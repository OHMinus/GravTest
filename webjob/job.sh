#!/bin/bash

# ===============================================
# 必須設定
# 環境変数としてApp Serviceの「構成」に設定することを推奨
# ===============================================

# GitHubのユーザー名/リポジトリ名 (例: your-user/your-repo)
GITHUB_REPO_SLUG="<YOUR_GITHUB_USER>/<YOUR_REPO_NAME>"

# Personal Access Token (PAT) - repoスコープ権限が必要
# PATを直接URLに含めるため、ここでは変数に格納
PAT="<YOUR_GITHUB_PAT>"

# ブランチ設定
SYNC_BRANCH="admin-sync"
MAIN_BRANCH="main"

# ===============================================
# スクリプト本体
# ===============================================

echo "--- Grav Auto Sync Start ---"

# 1. 動作ディレクトリの確認と移動
# App Serviceの/home/site/wwwroot (Gravのルートディレクトリ) に移動
if [ ! -d "/home/site/wwwroot/.git" ]; then
    echo "ERROR: Not a Git repository or directory is incorrect."
    exit 1
fi
cd /home/site/wwwroot

# 2. ローカルブランチを専用ブランチに切り替える
# 外部からの変更でAdmin Panelでの編集内容が上書きされないよう、
# 編集内容が残っていることを確認するため、一旦ブランチを切り替える
git checkout $SYNC_BRANCH

# 3. 変更の確認
# ローカルファイルシステム上の変更（Admin Panelによる編集）をチェック
if [ -z "$(git status --porcelain)" ]; then
    echo "No content changes detected. Exiting."
    echo "--- Grav Auto Sync End ---"
    exit 0
fi

# 4. コミットとプッシュ
echo "Changes detected. Committing and pushing to $SYNC_BRANCH..."
git add .
COMMIT_MESSAGE="Admin Panel Sync: $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$COMMIT_MESSAGE"

# PATを使用してプッシュ（認証情報がURLに含まれる）
if ! git push "https://${PAT}@github.com/${GITHUB_REPO_SLUG}.git" $SYNC_BRANCH; then
    echo "FATAL ERROR: Git push failed. Check PAT and network."
    echo "--- Grav Auto Sync End ---"
    exit 1
fi

# 5. プルリクエストの作成（GitHub APIを使用）
echo "Creating Pull Request via GitHub API..."

PR_TITLE="[Auto-PR] Admin Panel Changes: $(date '+%Y-%m-%d')"
PR_BODY="This is an automated Pull Request from Azure WebJob after Admin Panel modifications. Please merge."

# jqを使ってJSONペイロードを作成
PR_DATA=$(jq -n \
  --arg title "$PR_TITLE" \
  --arg body "$PR_BODY" \
  --arg head "$SYNC_BRANCH" \
  --arg base "$MAIN_BRANCH" \
  '{title: $title, body: $body, head: $head, base: $base}')

# GitHub Pull Request APIをcURLで呼び出し
curl -s -X POST \
  -H "Authorization: token $PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${GITHUB_REPO_SLUG}/pulls" \
  -d "$PR_DATA"

echo "Pull Request created successfully or already exists."
echo "--- Grav Auto Sync End ---"