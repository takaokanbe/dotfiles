---
name: gen-agents-md
description: AGENTS.md（Claude Code の CLAUDE.md と同一視される）をポインタ設計のベストプラクティスに従って新規作成、または既存ドキュメントをリライトするスキル。「AGENTS.md を作って」「CLAUDE.md を更新して」「エージェント用ドキュメントを整備して」「新規リポジトリをセットアップして」などの依頼で必ず発動すること。既存の CLAUDE.md / AGENTS.md が説明文中心で腐敗しそうに見える場合、50 行を大幅に超えている場合、新規リポジトリで agent 向けドキュメントがまだ無い場合にも積極的に使う。言語/フレームワーク非依存で動作する。
---

# gen-agents-md

エージェント向けルートドキュメントである `AGENTS.md`（Claude Code では `CLAUDE.md` としても参照される）を「ポインタ設計」原則に従って作成・更新するスキル。

## このスキルが目指す成果物

- **ポインタ中心**: 一次情報を本文で説明せず、実ファイルへのパス参照にする
- **コンパクト**: 推奨 ≤50 行、上限 200 行
- **単一ソース**: `AGENTS.md` を実体、`CLAUDE.md` を `AGENTS.md` への symlink として配置する（cross-agent 標準 + Claude Code 互換性）
- **腐敗検出可能**: ポインタ先が存在しなくなれば機械的に気付ける

## なぜポインタ設計なのか（理念）

1. **説明文は腐敗する、パス参照は腐敗を検出できる**。`make test -race` と本文に書くと Makefile が変わったときに乖離する。`Makefile` への参照 1 行なら Makefile 自体が唯一の真実になる。
2. **コードから導ける情報は書かない**。ディレクトリ構造、コマンド一覧、言語バージョン、ビルド手順は `ls` / Makefile / go.mod / package.json 等から自明なので、本文には書かず参照先を示す。
3. **コードから導けない規約だけ残す**。例: テスト assertion のスタイル、コミットメッセージ規約、アーキテクチャの依存方向。これらは grep しても出てこないので AGENTS.md 本文に書く価値がある。
4. **50 行制約は経験則**（Boris Cherny 流）。200 行を超えるとエージェントの遵守率が急落する。短さは守られるために重要。

この理念を踏まえ、本スキルは「説明を書きたくなる衝動」を抑え、常に**「既存ファイルへの参照で済ませられないか？」**を自問しながら書く。

## 実行手順

### Step 1: 現状の検出

作業対象のリポジトリルートで以下を確認する：

```bash
ls -la AGENTS.md CLAUDE.md 2>/dev/null
```

分岐：

| 状態 | モード | 方針 |
|---|---|---|
| `AGENTS.md` も `CLAUDE.md` も無い | **新規作成** | AGENTS.md を新規生成 + CLAUDE.md symlink 作成 |
| `CLAUDE.md` が通常ファイル、`AGENTS.md` 無し | **マイグレーション** | `git mv CLAUDE.md AGENTS.md` → 内容書き換え → symlink 作成 |
| `AGENTS.md` が実体、`CLAUDE.md` が `AGENTS.md` への symlink | **更新** | AGENTS.md を Edit で差分修正（symlink はそのまま） |
| 両方が実体ファイル、または `AGENTS.md` が symlink | **変則** | ユーザーに状態を報告し、どう統合するか確認してから進む |

既存内容がある場合は必ず Read で把握してから次へ進む。既存にある規約（ユーザー独自のルール）は消さないよう注意する。

### Step 2: 一次情報の探索

リポジトリ直下から 2 階層程度まで、以下のパターンを Glob で探す。**見つかったものだけ**を「一次情報の所在」セクションの候補にする。存在しないパスを書かないこと（腐敗検出の要）。

| カテゴリ | 探すパターン（例） |
|---|---|
| アーキテクチャ doc | `docs/architecture.md`, `docs/ARCHITECTURE.md`, `ARCHITECTURE.md` |
| ビルド/タスク | `Makefile`, `justfile`, `Taskfile.yml`, `package.json`, `pyproject.toml`, `Cargo.toml`, `build.gradle`, `pom.xml` |
| API 仕様 | `openapi/**/*.{yml,yaml,json}`, `swagger.{yml,yaml}`, `schema.graphql`, `proto/**/*.proto` |
| DB マイグレーション | `migrations/`, `db/migrate/`, `alembic/`, `prisma/migrations/` |
| コード生成設定 | `sqlc.yaml`, `codegen.yml`, `buf.gen.yaml`, `openapi-generator-config.*` |
| Lint 設定 | `.golangci.yml`, `.eslintrc*`, `ruff.toml`, `.rubocop.yml`, `clippy.toml`, `biome.json` |
| 型/スキーマ | `schema.prisma`, `schema.sql`, `*.proto` |
| 機能設計 | `docs/design/`, `docs/rfcs/`, `docs/adr/` |
| README（最後の砦） | `README.md` — 他に一次情報が薄い場合のみ参照する |

**言語非依存に扱うコツ**: 特定の言語固有ファイルに決め打ちしない。存在判定ベースで拾い、見つからないカテゴリは AGENTS.md から丸ごと省く。カテゴリが 2〜3 個しか無い小さなリポジトリなら、無理に埋めずスカスカで出力する方が正しい。

### Step 3: 規約のヒアリング

**コードから導けない規約**を短くユーザーに確認する。新規作成モードでは聞く、更新/マイグレーションモードでは既存 AGENTS.md から拾う（ユーザーに都度聞き直さない）。

聞くべきトピック（全部聞かず、関係ありそうなものだけ）:

- テスト assertion / フィクスチャの流儀（例: 「struct 全体比較」「table-driven を使う」）
- コミットメッセージ規約（Conventional Commits? その他?）
- アーキテクチャの依存方向（Clean Architecture、レイヤード、Hexagonal 等）
- ブランチ戦略 / PR ルール
- 言語/ツールバージョンの固定（`go.mod` / `.nvmrc` 等で分かる場合は書かない）

ユーザーが「分からない / 後で追加する」と答えたら、規約セクションは最小 or 空で良い。**無理に埋めるより空白を許容する**方がポインタ純度に沿う。

### Step 4: ドラフトの生成

以下の骨組みで書き起こす。セクションは**絶対必須ではない**ので、該当情報が無ければそのセクションごと省いて良い。

````markdown
# <プロジェクト名>

## 一次情報の所在

- <カテゴリ>: `<相対パス>`
- ... (Step 2 で見つかったものだけ)

## 規約

- **<規約名>**: 本文 or 参照先
- ... (Step 3 で聞き取ったもの or 既存から拾ったもの)

## 関連リポジトリ（任意）

- `<名前>` — 説明（GitHub: `<org>/<repo>`）。詳細は `<repo>/AGENTS.md` 参照。
  - ローカル標準配置: ...（worktree 対応が必要なら main checkout 経由の解決方法も短く）

## 頻出コマンド（全量は `<参照先>`）

```bash
# 最頻出の 3〜5 個だけ。全量は Makefile / package.json などに委譲
```

## 運用メモ

- エージェントがミスしたら「AGENTS.md を更新して次回同じ間違いをしないように」と伝え、反復更新する。
- 全体を 50 行以内（推奨）、長くても 200 行以内に保つ。詳細は別ファイルに移して参照する。
- ワークフローが変わったらコマンドをすぐ更新する。
````

**書き方のルール**
- タイトル以外は見出し 2（`##`）で統一
- 各行は 1 行 1 事実、ネストは最小限
- ポインタは常に backtick でファイル名を囲み（`docs/architecture.md`）、grep しやすくする
- 「〜する」「〜である」の説明文が書きたくなったら、その内容がコードから導ける場合は削除、導けない規約なら短く残す

### Step 5: 行数チェック

生成した AGENTS.md の行数を `wc -l` で確認する：

- **≤50 行**: ✅ OK
- **50〜200 行**: ⚠️ 警告を出し、ユーザーに短縮を提案。具体的には説明文を削る、参照先に委譲する、セクションを削る
- **>200 行**: ❌ 必ず短縮する。遵守率が急落するため受け入れ不可

短縮の優先順位: ①説明文の削除 → ②頻出コマンドを 3 個以下に絞る → ③一次情報リストを 5 個以下に絞る → ④セクション削除

### Step 6: ファイル物理構成の調整（AGENTS.md + CLAUDE.md symlink 強制）

モードに応じて実行：

**新規作成モード**
```bash
# Write tool で AGENTS.md を作成した後
ln -s AGENTS.md CLAUDE.md
```

**マイグレーションモード**
```bash
git mv CLAUDE.md AGENTS.md
# この時点で AGENTS.md は旧 CLAUDE.md の内容を持つ
# Edit tool で AGENTS.md の内容を新しい形に書き換える
ln -s AGENTS.md CLAUDE.md
git add CLAUDE.md   # symlink を staging
```

**更新モード**
```bash
# AGENTS.md は実体、CLAUDE.md は既存の symlink
# AGENTS.md を Edit で差分修正するだけ。symlink はそのまま
```

symlink 作成後、`cat CLAUDE.md | head -3` で AGENTS.md の内容が返ることを確認する。

**この symlink 構成は必ず強制する**。理由は cross-agent 標準（Cursor / Codex / Aider などが AGENTS.md を読む）に追従しつつ Claude Code 互換性を維持するため。ユーザーがオプトアウトを求めない限り常にこの形で出力する。

### Step 7: 検証

以下を順に確認：

1. **パス実在確認**: AGENTS.md に書いた全ポインタを Glob で存在確認する。1 つでも壊れていれば修正する
2. **行数確認**: `wc -l AGENTS.md` が目標内
3. **symlink 健全性**: `readlink CLAUDE.md` が `AGENTS.md` を指す
4. **差分提示**: `git diff --cached` と `git status` をユーザーに見せる。特にマイグレーションモードでは typechange が発生するので明示する

## アンチパターン（やらない）

- ❌ ディレクトリ構造の文章解説（`cmd/` には〜があり、`internal/` には〜がある）→ `ls` で分かる
- ❌ ビルド手順の羅列（`go build -o bin/foo ./cmd/foo` 等）→ Makefile / package.json 参照で済む
- ❌ コードパターンの説明（`FooRepository は Write に使う`）→ grep / ファイル名で分かる
- ❌ デプロイや CI/CD の詳細 → 別ドキュメントに外出しして参照
- ❌ 絶対パスやユーザー固有の環境変数 → git 管理下で全員共有するため不向き
- ❌ 腐敗しやすい統計値（カバレッジ %、行数など）
- ❌ 「現在の状況」（WIP、進行中タスク）→ CLAUDE.md は静的ドキュメント。動的状態は PR / issue に書く
- ❌ 存在しないファイルへのポインタ（想定、予定のファイルは書かない）

## 例外と許容

- 規約セクションが 1 項目 or 空でも OK。無理に詰めるより誠実
- 「関連リポジトリ」「頻出コマンド」も不要なら省略可
- 機能設計ドキュメント（`docs/design/`）は**ディレクトリ参照**で OK（個別ファイルを列挙しない。個別ファイルは腐敗する）
- README.md は通常参照しないが、docs/ が無いリポジトリでは README.md をポインタ先にしてよい

## 出力例

timeline-server という Go プロジェクトに対して本スキルが出力した実例（42 行）:

````markdown
# timeline-server

## 一次情報の所在

- アーキテクチャ / 依存ルール / Read・Write 分離 / テスト戦略: `docs/architecture.md`
- ビルド / テスト / lint / generate コマンド: `Makefile`
- HTTP API 仕様（管理面）: `openapi/admin.yml`
- HTTP API 仕様（プロダクト面）: `openapi/app.yml`
- DB スキーマ: `migrations/*.sql`
- sqlc 生成設定: `sqlc.yaml`
- Lint 設定: `.golangci.yml`
- 機能設計ドキュメント: `docs/design/`

## 規約

- **アーキテクチャ規約**（依存方向 / Read・Write 分離 / handler → usecase 強制 など）: `docs/architecture.md` 参照
- **テスト assertion は struct 全体比較**: `assert.Equal(t, expected, got)`。フィールド単位比較は禁止。
- **コミットメッセージ**: Conventional Commits。
- **Go / lint バージョン**: Go 1.26、golangci-lint v2（`default: all`）。

## 関連リポジトリ

- `ops` — インフラ定義（GitHub: `CyberAgentTeen/ops`）。詳細は `ops/AGENTS.md` を参照。
  - ローカル標準配置: 当リポジトリと同じ親ディレクトリに置く（main checkout から `../ops`）。
  - worktree から参照する場合は main checkout 側のパスで解決する（`git worktree list` の 1 行目が main）。

## 頻出コマンド（全量は `Makefile`）

```bash
make test         # -race -coverprofile 付き
make lint         # golangci-lint
make generate     # go generate 一括
make dev-run      # admin サーバをローカル起動
```

## 運用メモ

- エージェントがミスしたら「AGENTS.md を更新して次回同じ間違いをしないように」と伝え、反復更新する。
- 全体を 50 行以内（推奨）、長くても 200 行以内に保つ。詳細は別ファイルに移して参照する。
- ワークフローが変わったらコマンドをすぐ更新する。
````

この例は本スキルの理念を凝縮している: 説明ゼロ、参照中心、規約は短く、50 行制約遵守、symlink 対応済み。

## スコープ外（このスキルではやらない）

- `docs/architecture.md` の新規作成 → 別スキルまたは手動作業（内容が重く、言語非依存で自動生成するのは困難）
- サブディレクトリ別の AGENTS.md の生成
- `.claude/rules/` 以下の細則ファイルの生成
- GitHub PR / issue の操作

これらが必要なら別途ユーザーに提案し、本スキルの責任範囲外として扱う。
