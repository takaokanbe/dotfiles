---
name: address-pr-review
description: 現在のブランチの PR に対してレビュー生成・既存 PR コメント取込・優先度トリアージ・修正・CI 監視・ループ実行を、**並列 subagent + メイン集約 triage** で行うオーケストレーションスキル。`/codex:review`、`/codex:adversarial-review`、`/pr-review-toolkit:review-pr`、`gh` を Agent tool で並列起動し、全 finding 集約後に critical/high/medium/low の severity で対応範囲を制御する。
disable-model-invocation: true
---

# PR レビュー対応ループ

現在のブランチの Open PR に対して、新規レビュー生成・既存 PR コメント取込・優先度トリアージ・修正・CI 監視を反復実行する。
**FP 検証 + 閾値停止 + 実走検証 + 人間チェックポイント** を組み込み、infinite loop / validation hallucination / コスト暴走を避ける設計。

## Execution Contract

本 skill が守るべき不変条件のサマリ。違反は実行中断条件。詳細は各実行手順を参照。

### MUST（必ず守る）

- **Phase A の 3 slot 並列発行**：レビュー系 1 本（A or A'）+ B + C を **単一メッセージで並列発行** する（ステップ 2-2）
- **Phase 境界の遵守**：A→B→C→D→E の順序を厳守し、前フェーズ完了前に次に進まない
- **Triage 完了前の Edit/Write 禁止**：ステップ 5 のユーザー確認（または `--no-confirm` 適用）後にのみ修正を開始（ステップ 6 不変条件）
- **CI green 確認後にのみ再レビューへ**：ステップ 7.6 で CI watch 完了前にステップ 8 に進まない
- **人間レビュアーの指摘 (`pr-comment-human`) は降格しない**：セッション文脈での降格対象外（ステップ 4.5-3）
- **per-iteration push**：per-finding push と end-only push の両方を避ける（ステップ 7.5）

### FORBIDDEN（絶対にやらない）

- **途中結果での triage 開始**：3 slot 揃う前の集約は禁止
- **Skill tool をメインから直接呼ぶ**：レビュー skill は必ず subagent 内部から起動する（並列性確保のため、ステップ 2-2）
- **実走検証なしの `resolved` マーク**：ステップ 7 のローカル実走で通過してはじめて resolved
- **自動 merge**：人間 approve は本 skill の責務外
- **`git push --force` / `--no-verify`**：別 skill (`commit-push`) の規約に従い禁止
- **降格 2 段階超えの severity 操作**：critical → low の一気降格は禁止（ステップ 4.5-3）

## 実行フェーズ（時系列）

本 skill は 1 反復につき以下 5 フェーズを順に進める。**各フェーズ境界は明確に保ち、前フェーズが完了するまで次フェーズに進まない**。これは早期コミットや部分 triage による「PR の Copilot review だけ対応して完了した」ような症状を防ぐための不変条件。

| Phase | 内容 | 対応ステップ | 並列性 |
| --- | --- | --- | --- |
| **A. 並列レビュー** | レビュー系 1 本（A か A' のどちらか）+ B + C の **3 slot** を単一メッセージで並列発行し、全 return を待つ | 2 | 3 並列 |
| **B. 集約 + triage** | 正規化 → FP scoring → severity 分類 → セッション文脈反映 → ユーザー確認 | 3–5 | 一部並列 (FP scoring) |
| **C. 逐次修正** | severity 順に 1 件ずつ修正 → 実走検証 → resolve/blocked マーク | 6–7 | 直列 |
| **D. コミット + CI 監視** | iteration 単位でまとめて commit/push → CI green まで修正サブループ | 7.5–7.6 | 直列 |
| **E. 再レビュー or 終了** | iteration カウンタ更新 → 停止条件判定 → bot 再レビュー依頼 → 最終レポート | 8–10 | 直列 |

Phase 境界の不変条件：

- **A→B**：Agent 呼び出しの全 return を受領してから集約を始める。**途中結果で triage に進まない**
- **B→C**：ユーザー確認が完了するまで Edit / Write を実行しない
- **C→D**：その反復で resolve した finding が 0 件ならコミット自体スキップ
- **D→E**：CI green 確認前にステップ 8 の再レビュー判定に進まない

## 前提条件

- git リポジトリ内、feature ブランチに push 済み
- 現在のブランチで Open の PR が存在する（`gh pr view` で確認可能）
- `gh` が認証済み（`gh auth status` で確認）
- 以下が user scope で利用可能：
  - `/codex:review`、`/codex:adversarial-review`（codex プラグイン）
  - `/pr-review-toolkit:review-pr`（pr-review-toolkit プラグイン）
  - 未インストールなら `/plugin install pr-review-toolkit@claude-plugins-official` を案内して中断する

## 引数

- `--max-iterations <N>`  デフォルト **3**
- `--threshold <critical|high|medium|low>`  デフォルト **high**（high 以上を対応 = critical + high）
- `--no-confirm`  Triage 後の確認プロンプトを省略
- `--adversarial <auto|always|never>`  デフォルト **auto**。レビュー系 slot を **A (codex:review) と A' (codex:adversarial-review) のどちらで走らせるか** を選ぶ（排他）。`auto` は高リスク検出時に A' を選び、それ以外は A。`always` は常に A'、`never` は常に A。
- `--focus "<text>"`  A' に渡す焦点（指定時は `--adversarial always` 扱い → A' 選択）
- `--no-wait`  反復間の CI 完走待機をスキップ（CI 失敗修正サブループも丸ごとスキップされるため非推奨）
- `--ci-max-retries <N>`  CI 修正サブループの上限。デフォルト **3**

### `--no-confirm` × `--threshold` の関係

| `--no-confirm` | 動作 |
| --- | --- |
| 無し（デフォルト） | ステップ 5 で `AskUserQuestion` を出し、ユーザーが選んだ閾値で対応する。`--threshold` は **デフォルトの初期選択** に使う |
| **有り** | ステップ 5 をスキップし、**`--threshold` の値（明示無しなら `high`）をそのまま使う**。最終確認も無し |

`--no-confirm` 単体だと `critical + high` が対応対象。広げたい場合は `--no-confirm --threshold medium` のように併記する。
**安全側の設計**：`--no-confirm --threshold low` で全件対応するのは drift / コスト暴走リスクが高いため非推奨。可能ならユーザー判断を介す。

## 実行手順

### 1. 初期化 & PR 情報取得

```bash
gh pr view --json number,headRefName,baseRefName,url,headRepository,headRepositoryOwner -q '.'
```

- PR 番号 / URL / base ブランチ / 現在のブランチ名を取得し変数化
- Open PR が無ければ「現在のブランチで Open PR が見つかりません。`commit-push` skill で作成してから再実行してください」と報告して終了
- 反復回数 `n = 0` を初期化
- `--max-iterations`、`--threshold`、`--no-confirm`、`--adversarial`、`--focus`、`--no-wait`、`--ci-max-retries` をパース
- 対応 severity 集合を決定：
  - `critical` → `{critical}`
  - `high` → `{critical, high}`（**デフォルト**）
  - `medium` → `{critical, high, medium}`
  - `low` → `{critical, high, medium, low}`

### 2. 並列レビュー収集（1 反復の冒頭）

#### Phase A の不変条件

1 反復の Phase A では **必ず 3 本を単一メッセージで並列発行する**。欠けた状態で triage に進まない。

- **レビュー系 slot**：A か A' の **どちらか 1 本（排他）**
- **B**：`pr-review-toolkit:review-pr all`
- **C**：`gh api pulls/issues/reviews`

過去に「Copilot review（C）だけで triage が始まる」「slot A 自体が発行されず落ちる」事象があり、その再発を構造的に防ぐための不変条件。3 本揃わない場合は発行を止めて 2-1 からやり直す。

A と A' は排他：同一 Codex 系統の 2 バリアント（builder vs critic）で独立性が限定的なため、クロス検証は **レビュー系 × B × 人間/bot** の異系統軸に委ねる。echo chamber 破壊は別系統の B で担保される。

#### 2-1. レビュー系 slot の選択（A か A'）

`--adversarial` と高リスク判定で **どちらを 1 本発火させるか** を決める：

| `--adversarial` | 高リスク判定 | 発火 slot |
| --- | --- | --- |
| `never` | — | **A**（codex:review） |
| `auto`（デフォルト）| 非該当 | **A** |
| `auto` | **該当** | **A'**（codex:adversarial-review） |
| `always` or `--focus` 指定 | — | **A'** |

高リスク判定（`auto` 時のみ評価）：以下いずれかが真なら該当。

- 変更パスに `auth`, `login`, `session`, `token`, `crypt`, `secret`, `payment`, `billing`, `migration`, `schema`, `.env`, `iam`, `permission` のいずれかを含む
- `git diff --shortstat <base>...HEAD` の合計変更行が **500 行超**
- base ブランチが `main` / `master` かつ diff にマイグレーションファイル（`migrations/`, `db/schema`, Alembic 等）を含む

`--focus "<text>"` が渡されたら A' に focus を転送する。

#### 2-2. Pre-flight チェックリスト → 並列発行

Agent/Bash tool を発行する **直前** に以下テンプレを main の発話として出力する。3 本揃っていない発行は self-verification で止める。

```
Phase A 発行予定（3 slot 必須）:
- レビュー系: [A | A']  ← どちらか 1 本
  選択根拠: <--adversarial=… / 高リスク判定=…>
- B: pr-review-toolkit:review-pr all  (Agent tool)
- C: gh api pulls/issues/reviews      (Bash tool × 3)
→ この 3 本を単一メッセージで発行する。欠けたら中止し 2-1 に戻る。
```

テンプレ出力後、単一メッセージで以下を発行する：

- **レビュー系**：`Agent(subagent_type="general-purpose", …)` を 1 本。内部で Skill tool を呼ぶ（A → `codex:review --wait` / A' → `codex:adversarial-review --wait [--focus "..."]`）
- **B**：`Agent(subagent_type="general-purpose", …)` を 1 本。内部で Skill tool で `pr-review-toolkit:review-pr all`
- **C**：`Bash tool` を 3 本（`pulls/comments` / `issues/comments` / `pulls/reviews`）

**Skill tool をメインから直接呼ばない**。メインコンテキストで同期実行され並列にならないため、レビュー skill の起動は必ず subagent 内部から行う。全 return を受領するまで triage に進まない。

**Slot 表**（排他化後）：

| 並列 slot | 担当 | メインからの呼出し | 内部コマンド |
| --- | --- | --- | --- |
| A または A' | A=実装欠陥検出 / A'=設計・前提への挑戦 | `Agent(subagent_type="general-purpose", …)` | Skill tool で `codex:review --wait` または `codex:adversarial-review --wait` |
| B | セキュリティ / テスト / 型 / 静黙失敗の観点網羅 | `Agent(subagent_type="general-purpose", …)` | Skill tool で `pr-review-toolkit:review-pr all` |
| C | 人間 / bot の実レビューコメント取得 | `Bash(command="gh api …")` × 3 | — |

**subagent プロンプトの共通形式**：

1. 呼ぶ slash command と引数を明示（`/codex:review --wait` 等）
2. 結果を **ステップ 2-3 の JSON schema に正規化して返す**
3. 正規化できない情報は `raw_output` に raw テキストで添付
4. `source` に slot 識別子（`"codex"` / `"codex-adversarial"` / `"pr-review-toolkit"`）を埋める
5. **修正の提案・実施は禁止**（Phase C で行う）

A' のみ JSON（`approve` / `needs-attention` + 0.0–1.0 confidence + file:line）が返るので `codex_confidence` に値を詰める。A はテキスト出力のため `codex_confidence: null`。

**Slot C の bash コマンド**：

```bash
gh api "repos/${OWNER}/${REPO}/pulls/${PR}/comments" --paginate
gh api "repos/${OWNER}/${REPO}/issues/${PR}/comments" --paginate
gh api "repos/${OWNER}/${REPO}/pulls/${PR}/reviews" --paginate
```

Claude Code の harness は複数 tool 呼び出しを並列実行し、全 return を集めて一度に tool_result を返す。メインは次ターンで全 slot の結果を受け取る。

#### 2-3. return 検証 + findings の正規化

**return 検証**：受領した tool_result から `source` のユニーク集合を作り、以下 3 系統が揃ったことを確認する：

1. `codex` **または** `codex-adversarial`（レビュー系 1 本）
2. `pr-review-toolkit`（B）
3. `pr-comment-*`（C）

欠落があれば **1 回だけ当該 slot を再発行** する（ネットワークや subagent の瞬間的な失敗を救う）。再発行後もなお欠けていれば「Phase A の 3 slot のうち <slot> が受領できませんでした」と明示してユーザー判断を仰ぎ、**揃わない状態で triage に進まない**。

**正規化**：全結果を統一 schema に畳み込む：

```jsonc
{
  "id": "<hash>",
  "source": "codex" | "codex-adversarial" | "pr-review-toolkit" | "pr-comment-human" | "pr-comment-bot:<botname>",
  "file": "<path or null>",
  "line": "<number or null>",
  "raw_severity": "<string>",
  "message": "<text>",
  "suggested_fix": "<text or null>",
  "thread_id": "<string or null>",      // gh の resolvable thread 用
  "codex_confidence": "<0.0-1.0 or null>", // codex-adversarial のみ値あり。codex:review はテキスト出力なので null
  "raw_output": "<text or null>"        // 正規化できなかった raw レスポンスの保全
}
```

### 3. False Positive 検証 + クロス検証ボーナス

#### 3-1. 個別 confidence scoring

各 finding に対し **独立な Agent tool 呼び出しを単一メッセージでまとめて発行** して 0–100 の confidence scoring を並列実施する（`subagent_type=general-purpose`）。
findings が 20 件を超える場合は 20 件ずつバッチ並列化（1 メッセージあたり最大 20 Agent 呼び出し）。

ルブリックは `/code-review:code-review` の既存ルブリック（0/25/50/75/100）を流用：

- **0**: 明らかな FP / 既存問題
- **25**: 怪しい
- **50**: 実在するが nitpick
- **75**: 実在し影響大
- **100**: 確実

評価 prompt には CLAUDE.md / REVIEW.md（存在すれば）をコンテキストとして渡す。
**`codex_confidence` が入っているのは `source: codex-adversarial` のみ**（`codex:review` はテキスト出力のため null）。adversarial 由来の finding は `codex_confidence * 100` を初期値として採用し、scoring agent が調整する。

#### 3-2. クロス検証ボーナス

A と A' は排他（同一 Codex 系統）なので、クロス検証は **異系統軸** に委ねる。「異なる系統の複数 source が同じ問題を指摘したら信頼度を上げる」原則：

- **レビュー系（A または A'）と B の両方で指摘**：**+20**
- **レビュー系 / B と `pr-comment-bot:*`（Copilot / CodeRabbit 等）で一致**：**+25**
- **人間レビュアー（`pr-comment-human`）で指摘**：**無条件 100**（人間の判断を尊重）

#### 3-3. 閾値フィルタ

- **≥ 60** のみ triage 対象に残す
- ただし `source` が `pr-comment-human` のものは無条件で残す（人間の指摘を切り捨てない）

### 4. Severity トリアージ

残った findings を以下にマッピング：

| 入力 | 出力 severity |
| --- | --- |
| `blocking` / `critical` / security / 認証壊す / データ破壊 / **codex-adversarial で `needs-attention` 判定** | **critical** |
| `important` / logic bug / race condition / API 契約違反 / codex(-adversarial) で confidence ≥ 0.7 | **high** |
| `nit`（高 confidence）/ 保守性 / テスト漏れ / 複雑度 / パフォーマンス | **medium** |
| `suggestion` / `learning` / `praise` / スタイル / 命名 | **low** |

重複 finding（同一 file + 近接 line + 類似 message）は **マージ** し、source 欄に複数タグを付記。
`codex-adversarial` は「設計レベルの指摘」なので、`suggestion` や `nit` には基本分類されない（adversarial プロンプト自体が style feedback を除外しているため）。

### 4.5. セッション文脈による pre-triage（呼出し側エージェントの記憶を活用）

**目的**：本 skill は呼出し側のメインエージェント内で実行される。そのエージェントは **当該セッション中の会話履歴（過去の判断、議論、保留事項）** を持っている。これを優先度調整に使う。

#### 4.5-1. セッション照合

ステップ 4 でランク付けされた findings を、以下の観点でメインエージェントの会話文脈と照合する：

| セッション中の状況 | 反映 |
| --- | --- |
| 同じ問題を議論済みで「**意図的にそうしている**」と結論済み | severity を **2 段階下げる**（例：critical → medium）+ `session_status: accepted` |
| 議論済みで「**別 PR で対応する**」と決定済み | severity を **low** に降格 + `session_status: deferred` + 理由を attached |
| 議論済みで「**修正する**」と決定済み | severity 維持 + `session_status: confirmed` |
| 議論済みで「**仕様 / トレードオフ**」と判断済み | severity を **1 段階下げる** + `session_status: discussed-tradeoff` |
| ユーザーから明示的に「**これは見なくていい / 無視して**」と指示済み | **対応対象から除外** + `session_status: dismissed` |
| ユーザーから「**この観点は重要**」と強調された領域に該当 | severity を **1 段階上げる** + `session_status: emphasized` |
| 議論なし（新規） | 変更なし + `session_status: new` |

#### 4.5-2. 判定の根拠記録

各 finding に対し、降格 / 昇格 / 除外を行った場合は **根拠の引用**（会話の該当箇所要約 1–2 文）を `session_reasoning` フィールドに記録する。
これは：

- ステップ 5 のユーザー確認画面で「なぜこの critical を medium に落としたか」を提示するため
- ステップ 10 の最終レポートで「skip 理由」として残すため

#### 4.5-3. 慎重に扱う原則

- **人間レビュアーの指摘（`pr-comment-human`）は降格しない**：セッション内で「許容」と判断していても、PR 上で明示的に指摘されたものはユーザーに見せて改めて判断を仰ぐ
- **adversarial-review 由来の `needs-attention` は降格しても最低 high まで**：echo chamber を防ぐため、別系統 AI が出した強い警告を session 文脈だけでゼロにしない
- **降格は 2 段階まで**：critical → low の一気降格は禁止（過度の自己肯定を防ぐ）

#### 4.5-4. 出力形式（次ステップへ）

ステップ 5 に渡す findings には ステップ 2-3 の schema に加え、`original_severity`・`adjusted_severity`・`session_status`（`new` / `accepted` / `deferred` / `confirmed` / `discussed-tradeoff` / `dismissed` / `emphasized`）・`session_reasoning` が付く。

### 5. ユーザー確認

`--no-confirm` でない場合は `AskUserQuestion` で確認。
セッション pre-triage で **降格 / 除外された finding がある場合は明示** する。

提示テンプレート：

```
Triage 結果（セッション文脈反映後）:
- critical: N 件 / high: N / medium: N / low: N / 除外: N
- セッションで降格された主な finding があれば [元 severity → 現 severity] file:line と根拠 1 行で列挙

どこまで対応しますか？ [critical + high（推奨）] [+ medium] [全対応] [中断]
```

選択結果で対応 severity 集合を更新。
`session_status: dismissed` の finding は最終レポートに残すが、対応対象には含めない。

### 6. 修正フェーズ

**前提条件（Phase C の不変条件）**：

- ステップ 5 のユーザー確認（または `--no-confirm` 時は閾値適用）が完了している
- **triage 完了前に Edit / Write を実行してはならない**。ステップ 2〜5 の間にコード修正を始めると、後続 finding と衝突して差分が汚染される

対象 severity の findings を **1 件ずつ逐次** 処理：

1. finding の file/line を読み、周辺コードを理解
2. 修正を実施（Edit）
3. ステップ 7（実走検証）へ
4. 成功なら finding を `resolved` マーク、次へ
5. 失敗なら実走のエラー出力を context に加えて **サブループ上限 3 回** 再修正
6. 3 回超えても失敗なら `blocked` マークして次へ（最終レポートに残す）

### 7. 修正結果の実走検証（ローカル）

リポジトリの CLAUDE.md / README に記載のテスト・lint コマンドを優先採用。
無ければフォールバック：

| 言語 / framework | コマンド |
| --- | --- |
| Node | `npm test && npm run lint` 等 |
| Python | `pytest && ruff check` |
| Go | `go test ./... && go vet ./...` |
| Neovim (lua) | `stylua --check` |

**実際に実行して出力を読む** こと。「通ったはず」は禁止（validation hallucination 対策）。

### 7.5. コミット & プッシュ（反復ごと）

#### 設計方針

- **per-finding push しない**（細かすぎ、CI / Built-in Code Review が毎回走るとコスト暴走）
- **per-iteration push する**（1 反復で対応した findings をまとめて 1 コミット → 1 プッシュ）
- **end-only push にしない**（Bot 再レビューは push されないと意味がないので、最低 1 push は必要）

#### 7.5-1. コミット

その反復で resolved になった findings を集計し、コミットを作成：

```bash
git add <修正したファイル群>  # git add -A は使わない（commit-push skill 規約に準拠）
git commit -m "fix: address review findings (iteration <n>)

- [critical] auth/session.ts: token refresh race
- [high] api/users.ts: missing tenant scope
- [high] db/migration_2026_04_15.sql: backfill not idempotent

Refs: <PR URL>
"
```

- type は基本 `fix:`、refactor 性が強ければ `refactor:`
- subject に「review findings 対応」明記
- body に対応した findings を severity 付きで列挙
- **失敗（blocked）の finding はコミットに含めない**（次反復に持ち越し）
- **コミット対象が無ければスキップ**（fix が 0 件の反復は push もスキップ）

#### 7.5-2. プッシュ

```bash
git push origin <現ブランチ>
```

push 後に：

- リポジトリの Built-in Code Review trigger が `after every push` 設定なら、新しいレビューが自動起動する → 次反復のステップ 2 (slot C) で取り込まれる
- そのため push と次反復の開始の間に、ステップ 7.6 で適切な待機を挟む

### 7.6. CI 監視 & CI 失敗修正サブループ

push したらまず **CI が green になるまで** 必ず待つ。CI が赤なら修正→再 push を **CI が通るまで** サブループする。
**ステップ 8（再レビュー）には CI green 確認後でないと進まない。**

#### 7.6-1. CI 完走待機

```bash
gh pr checks <PR番号> --watch --interval 30
```

- 完了状態（success / failure / cancelled）になるまでブロック
- 30 秒ごとに状態確認
- 全体の wait timeout は **30 分**（超過したらユーザーに状況を報告して中断判断を仰ぐ）
- `--no-wait` フラグが指定されていれば、このステップ自体をスキップ（CI 結果を見ずに次反復へ）

#### 7.6-2. CI green の場合

ステップ 8（再レビュー）へ進む。

#### 7.6-3. CI red の場合 — CI 修正サブループ

`ci_retry = 0`、上限 `--ci-max-retries`（デフォルト 3）でループ：

1. 失敗したジョブのログを取得：

   ```bash
   RUN_ID=$(gh run list --branch "<ブランチ>" --limit 1 --json databaseId -q '.[0].databaseId')
   gh run view "$RUN_ID" --log-failed
   ```

   大きい場合は `--log-failed | tail -200` 等で要約。

2. 失敗の種類を判別：
   - **コードのバグ / テスト失敗** → 該当ファイルを修正
   - **flake（再実行で通る可能性）** → 1 回だけ rerun 許可（`gh run rerun "$RUN_ID" --failed`）
   - **インフラ / 権限エラー** → 自動修正不可と判断、ユーザー報告して中断
   - **lint / format** → 自動修正実施

3. 修正後、**ローカルで該当テスト / lint を再実走**（ステップ 7 と同じコマンド）して失敗が再現しないことを確認

4. コミットしてプッシュ：

   ```bash
   git add <修正したファイル>
   git commit -m "fix(ci): <短い説明> (iteration <n>, ci-retry <ci_retry>)"
   git push origin <ブランチ>
   ```

5. ステップ 7.6-1 に戻る（再度 CI watch）

6. `ci_retry = ci_retry + 1`

7. **ループ脱出条件**：
   - CI green になった → ステップ 8 へ
   - `ci_retry >= --ci-max-retries` → CI 失敗を `blocked` として最終レポートに記録、レビューループ全体も中断（人間判断を仰ぐ）
   - 同じ失敗が 2 連続で発生 → 同じ修正アプローチが効いていないと判断、中断して人間に報告

#### 7.6-4. CI 修正に伴う finding 状態の更新

CI 修正で新たに変更したファイルが、ステップ 6 で対応した finding と関連する場合：

- 当該 finding の `session_reasoning` に「CI 失敗で再修正、最終的に通過」を追記
- ステップ 8 の再レビューで、その finding が再度浮上していないことを確認（浮上していれば修正は実質不十分）

### 8. 再レビューとループ判定

**前提**：ステップ 7.6 で CI green 確認済み。

- `n = n + 1`
- 停止条件：
  - `n >= max-iterations`、**または**
  - 対象 severity に属する未対応 finding が 0、**または**
  - 直前の反復で resolved finding が 0（収束しないループの早期終了）、**または**
  - CI 修正サブループが上限超過（ステップ 7.6-3 の脱出経路）
- 継続条件なら ステップ 2 へ

### 9. Bot 向け再レビュー依頼

対応済み finding の source を走査：

| source | アクション |
| --- | --- |
| `pr-comment-bot:codex` | `gh pr comment <N> --body "@codex review"` |
| `pr-comment-bot:coderabbit` | `gh pr comment <N> --body "@coderabbitai review"` |
| `pr-comment-bot:greptile` | `gh pr comment <N> --body "@greptileai review"` |
| `pr-comment-human` | `gh pr edit <N> --add-reviewer <user>` で re-review 要請 |
| `thread_id` 付き | `gh api graphql -f query='resolveReviewThread'` で thread を解決 |

**順序**：thread を resolve → bot 再レビュー依頼の順で送る（順序保証のため）。

### 10. 最終レポート & 人間への引き渡し

以下フォーマットで報告：

```
## PR レビュー対応結果

PR: <URL>
反復回数: n / max_iterations
対応閾値: high 以上

### 対応済み
- [critical] <msg>（<file>:<line>）— 修正済み、tests 通過
- [high] ...

### 意図的スキップ
- [medium] <msg> — 閾値外
- [low] ...

### セッション文脈で降格した finding
- [元 critical → medium] <msg> — 根拠: "別 PR で対応" と合意済み

### 対応失敗（ブロッカー）
- [high] <msg> — 3 回修正試行したが tests 通らず、要人間判断

### 再レビュー依頼
- @codex review を送信
- レビュアー @user に re-review 要請

### 最終確認
ここから先は人間の判断です。**自動 merge しません**。
`gh pr view --web` で最終確認してください。
```

## エラーハンドリング

- **Open PR 無し**：「現在のブランチで Open PR が見つかりません。`commit-push` skill で作成してから再実行してください」と報告して終了
- **`gh` 未認証**：`gh auth status` で検出、`gh auth login` を案内して終了
- **`/codex:review` / `/codex:adversarial-review` / `/pr-review-toolkit:review-pr` 無し**：`/plugin install` を案内し、利用可能な slot だけで続行する旨をユーザーに確認
- **CI 完走 timeout（30 分超）**：状況を報告し、`--no-wait` で続行するか中断するかユーザーに判断を仰ぐ
- **同一 CI 失敗が 2 連続**：自動修正の有効性に疑義あり、中断して人間判断を求める
- **修正ループでの finding `blocked`**：最終レポートに残し、人間に引き継ぐ

## 完了基準

- すべての対応対象 finding が `resolved` か `blocked` のいずれか
- 最終レポートをユーザーに提示
- 人間の approve は **待たない**（auto-merge しない設計）

---

## 補遺：`/codex:review` と `/codex:adversarial-review` の使い分け

A と A' は **排他** で、`--adversarial` フラグと高リスク判定（ステップ 2-1）でどちらを Phase A のレビュー系 slot に据えるかを決める。

| 観点 | A: `/codex:review` | A': `/codex:adversarial-review` |
| --- | --- | --- |
| 立ち位置 | 標準レビュー・バグ検出 | **挑戦レビュー**「出すべき変更か」を問う |
| 対象 | 実装の正しさ | 設計・前提・トレードオフ |
| 含める指摘 | 実装欠陥・スタイル含 | material findings のみ（style 除外） |
| `--focus <text>` | 不可 | 可（指定で A' 強制選択） |
| 出力 | テキスト | JSON（`approve`/`needs-attention` + 0-1 conf + file:line） |
| 選択される時 | `--adversarial=never` / auto 非該当 | `--adversarial=always` / `--focus` / auto 該当 |

**Builder–Critic 分離**：同モデルに「自己チェック」させるより、echo chamber は **異系統軸** で破る — 本 skill では A（または A'）× B（pr-review-toolkit）× 人間/bot の 3 軸クロス検証（ステップ 3-2）が担う。A と A' の併走は同一 Codex 系統で独立性が薄いため採らない。

**adversarial 由来 finding の severity**：`needs-attention` → critical、`codex_confidence ≥ 0.7` → high（ステップ 4）。
