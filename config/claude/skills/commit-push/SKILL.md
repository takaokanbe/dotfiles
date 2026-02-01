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

### 1. 事前チェック

以下を確認する:

```bash
git status
git diff --stat
```

- コミット対象の変更があるか
- 意図しないファイルが含まれていないか

問題があれば処理を中断し、ユーザーに報告する。

### 2. 現在のブランチと PR 状態の確認

```bash
git branch --show-current
gh pr list --head $(git branch --show-current) --state open --json number,title
```

- 現在のブランチ名を取得
- 同じブランチで Open の PR が存在するか確認

### 3. ブランチ戦略の決定

Open の PR が存在しない場合:

- 現在のブランチでコミット・プッシュし、新規に PR を作成する

Open の PR が存在する場合:

- 現在のブランチのままコミット・プッシュし、既存 PR を更新する

```bash
git switch -c <新しいブランチ名>
```

### 4. コミットメッセージの作成

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

### 5. コミットの実行

```bash
git add -A
git commit -m "<type>: <subject>"
```

### 6. PR 作成前のコミット確認

ベースブランチ（main）との差分を確認:

```bash
git log main..<現在のブランチ> --oneline
```

- 意図しないコミットが含まれていないか確認
- 問題があればユーザーに報告し、処理を中断

### 7. リモートへのプッシュ

```bash
git push -u origin <ブランチ名>
```

### 8. PR の作成

Open PR がない場合のみ PR を作成:

```bash
gh pr create --title "<type>: <subject>" --body "<description>"
```

PR タイトル:

- コミットメッセージと同じ形式（`<type>: <subject>`）
- バリデーションルールに従う（小文字で開始）

PR description:

- `.github/PULL_REQUEST_TEMPLATE.md` のテンプレートに従う
- 各セクションを適切に埋める

### 9. PR 作成後の確認

```bash
gh pr view --web
```

- PR が正しく作成されたことを確認
- PR の URL をユーザーに報告

## エラーハンドリング

コミット対象がない場合:

```
コミット対象の変更がありません。
```

バリデーションエラーが予想される場合:

```
PR タイトルがバリデーションルールに違反する可能性があります:
- subject は小文字で開始してください
- 許可される type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
```

意図しないコミットが含まれる場合:

```
以下のコミットが PR に含まれます。意図した変更か確認してください:
<コミット一覧>

続行しますか？
```

## 出力例

```
実行結果:
- ブランチ: feat/add-new-feature
- コミット: feat: add user authentication
- PR: https://github.com/owner/repo/pull/123
- 含まれるコミット数: 1
```

Open PR が存在する場合:

```
Open の PR が見つかったため、新規作成はせず既存 PR を更新します:
- PR: <url>
```
