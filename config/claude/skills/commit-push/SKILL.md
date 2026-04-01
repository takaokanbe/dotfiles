---
name: commit-push
disable-model-invocation: true
---

# コミット・PR 作成コマンド

変更をコミットし、GitHub に PR を作成する。

## 前提条件

- git リポジトリ内で実行すること
- コミット対象の変更があること
- GitHub CLI (`gh`) が認証済みであること

## 実行手順

### 1. 状態の確認

以下を並列で実行し、現在の状態を把握する:

```bash
git status
git diff --stat
git log --oneline -5
```

確認すること:

- コミット対象の変更があるか
- 未追跡ファイルに機密情報が含まれていないか（次のステップで詳しくチェックする）

変更がなければ「コミット対象の変更がありません。」と報告して終了する。

### 2. 機密ファイルのチェック

`git status` の出力に以下のパターンに一致するファイルがないか確認する:

- `.env`, `.env.*`, `.env.local`
- `credentials.json`, `service-account*.json`
- `*.pem`, `*.key`, `*.p12`, `*.pfx`
- `.secret`, `secrets.*`
- `*_rsa`, `*_dsa`, `*_ed25519`

該当ファイルが見つかった場合:

1. ユーザーに警告する（ファイル名と除外する旨を明示）
2. そのファイルは絶対にステージングしない
3. `.gitignore` に含まれていない場合は追加を提案する（自動では変更しない）

### 3. 現在のブランチと PR 状態の確認

```bash
git branch --show-current
```

ベースブランチを特定する（`main` または `master`。両方存在する場合は `main` を優先）:

```bash
git rev-parse --verify main 2>/dev/null && echo main || echo master
```

現在のブランチで Open の PR があるか確認する:

```bash
gh pr list --head "$(git branch --show-current)" --state open --json number,title,url
```

### 4. ブランチ戦略の決定

**ケースA: 現在のブランチがベースブランチ（main/master）の場合**

新しいブランチを作成する。ブランチ名は変更内容から `<type>/<短い説明>` の形式で命名する:

```bash
git switch -c <type>/<短い説明>
```

例: `feat/add-auth`, `fix/login-null-pointer`, `chore/update-settings`

**ケースB: フィーチャーブランチにいて、Open の PR がない場合**

現在のブランチのままコミット・プッシュし、新規に PR を作成する。

**ケースC: フィーチャーブランチにいて、Open の PR がある場合**

現在のブランチのままコミット・プッシュし、既存の PR を更新する。新規 PR は作成しない。

### 5. コミットメッセージの作成

変更内容を分析し、以下の形式でコミットメッセージを作成する:

```
<type>: <subject>
```

type の選択基準:

| type     | 用途                                       |
| -------- | ------------------------------------------ |
| feat     | 新機能の追加                               |
| fix      | バグ修正                                   |
| docs     | ドキュメントのみの変更                     |
| style    | コード整形（機能に影響なし）               |
| refactor | リファクタリング（機能追加・バグ修正なし） |
| perf     | パフォーマンス改善                         |
| test     | テストの追加・修正                         |
| build    | ビルドシステム・外部依存の変更             |
| ci       | CI/CD の変更                               |
| chore    | その他の変更                               |
| revert   | コミットの取り消し                         |

subject のルール:

- 小文字で開始すること（大文字で始めるとバリデーションエラー）
- 簡潔に変更内容を記述（50文字以内推奨）
- 末尾にピリオドを付けない

例:

- `feat: add user authentication`
- `fix: resolve null pointer exception in login`
- `docs: update README with installation instructions`

### 6. ステージングとコミット

コミット対象のファイルを **個別に** ステージングする。`git add -A` や `git add .` は使わない:

```bash
git add <ファイル1> <ファイル2> ...
```

ステージング後、含まれるファイルを確認する:

```bash
git diff --cached --name-only
```

意図しないファイルが含まれていないことを確認してからコミットする:

```bash
git commit -m "<type>: <subject>"
```

### 7. PR 作成前のコミット確認

ベースブランチとの差分を確認する（ベースブランチ名はステップ 3 で特定したものを使用）:

```bash
git log <ベースブランチ>..<現在のブランチ> --oneline
```

意図しないコミットが含まれている場合はユーザーに報告し、続行するか確認する。

### 8. リモートへのプッシュ

```bash
git push -u origin <ブランチ名>
```

### 9. PR の作成または更新、ブラウザで開く

**ケースA・B（新規 PR 作成）の場合:**

PR を作成し、その後ブラウザで開く:

```bash
gh pr create --title "<type>: <subject>" --body "<description>"
gh pr view --web
```

PR タイトル:

- コミットメッセージと同じ形式（`<type>: <subject>`）

PR description:

- `.github/PULL_REQUEST_TEMPLATE.md` が存在すればそのテンプレートに従う
- 存在しなければ、変更の概要を簡潔に記述する

**ケースC（既存 PR 更新）の場合:**

PR 作成はスキップし、既存の PR をブラウザで開く:

```bash
gh pr view --web
```

### 10. 完了報告

PR の URL をユーザーに報告する。URL は `gh pr view --json url -q .url` で取得できる。

新規 PR の場合:

```
実行結果:
- ブランチ: <ブランチ名>
- コミット: <コミットメッセージ>
- PR: <PR URL>
- 含まれるコミット数: <数>
```

既存 PR 更新の場合:

```
既存の PR を更新しました:
- ブランチ: <ブランチ名>
- コミット: <コミットメッセージ>
- PR: <PR URL>
```

## エラーハンドリング

コミット対象がない場合:

```
コミット対象の変更がありません。
```

プッシュが拒否された場合（権限エラー等）:

```
プッシュが拒否されました。ブランチ名やリモートの設定を確認してください。
```

バリデーションエラーが予想される場合:

```
PR タイトルがバリデーションルールに違反する可能性があります:
- subject は小文字で開始してください
- 許可される type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
```
