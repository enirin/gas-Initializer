# GAS プロジェクト初期化スクリプト

Windows 環境で対話的に GAS プロジェクトの初期化を行うスクリプトです。メンバー配布を前提に、以下を自動実行します。

- 開発用フォルダの作成
- `clasp clone` で Apps Script ファイルをダウンロード
- `artifacts/.github/workflows/deploy-gas.yml` を新規プロジェクトの `.github/workflows/` に配置
- Git 初期化と初回コミット
- GitHub リモートリポジトリ設定
- `develop` / `main` ブランチの作成とプッシュ
- GitHub Environments の secret 登録

## 必須準備

### 1. clasp のインストール

PowerShellまたはコマンドプロンプトを管理者権限で開き、以下を実行：

```powershell
npm install -g @google/clasp
```

### 2. clasp のログイン

```powershell
clasp login
```

ブラウザが開き、Googleアカウント認証を求められます。  
認証後、`~/.clasprc.json` に認証情報が保存されます。

### 3. GitHub の準備

- 組織の空リポジトリを作成（例: `https://github.com/enirin/production-portal.git`）
- Personal Access Token（PAT）を生成し、ローカル認証に設定
  - 参考: [GitHub Docs - Personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

### 4. GitHub CLI の準備

GitHub Environments の secret 登録には GitHub CLI が必要です。

#### インストール

Windows では、PowerShell から以下を実行してください。

```powershell
winget install --id GitHub.cli -e
```

または、[GitHub CLI 公式](https://cli.github.com/) からインストーラーを取得して導入してください。

```powershell
gh auth login
```

### 5. Apps Script プロジェクト ID の取得

1. ブラウザで Apps Script エディタを開く
2. 左側メニューの「⚙️ プロジェクトの設定」をクリック
3. 「スクリプト ID」をコピー

## 使用方法

### ステップ1: スクリプト取得

このスクリプトをプロジェクトリポジトリに含める、または以下からダウンロード：

```
init-gas-project.bat    ← これをダブルクリック
init-gas-project.ps1
```

### ステップ2: 実行

**方法A: ダブルクリック**

`init-gas-project.bat` をダブルクリックします。

事前確認だけ先に行いたい場合は、`check-gas-init-prerequisites.bat` を実行してください。

**方法B: PowerShellから実行**

```powershell
powershell -ExecutionPolicy Bypass -File ".\init-gas-project.ps1"
```

### ステップ3: 対話的な入力

スクリプトが以下を順に聞きます。各項目に入力：

1. **フォルダの場所**
   - デスクトップまたは任意の場所を指定
   - デフォルトはデスクトップ

2. **フォルダ名**
   - 通常は `production-portal` のままでOK

3. **Apps Script スクリプト ID**
   - 上記で取得したID（長くて不規則な英数字）を貼り付け

4. **GitHub リポジトリ URL**
   - 例: `https://github.com/enirin/production-portal.git`
   - HTTPSまたはSSH形式両対応

5. **GitHub認証**
   - Personal Access Token（PAT）を求められたら入力

6. **Environment secret 登録**
   - `production` を含む対象 environment を入力
   - `CLASP_DEPLOYMENT_ID` は未設定なら Enter のままでOK

### 事前確認だけ実行する場合

以下のスクリプトで、`clasp login` と `gh auth login` を含む前提条件を確認できます。

```powershell
check-gas-init-prerequisites.bat
check-gas-init-prerequisites.ps1
```

Note: If old local files are used, PowerShell parser errors can occur because of encoding differences. Always pull the latest `develop` before running any `.ps1` script.

不足があった場合は、次のインストールスクリプトを実行してください。

```powershell
installers/install-gas-prerequisites.bat
installers/install-gas-prerequisites.ps1
```

Note: If old local files are used, PowerShell parser errors can occur because of encoding differences. Always pull the latest `develop` before running any `.ps1` script.

### ステップ4: 完了

以下が自動実行されます：

✓ フォルダ作成  
✓ clasp clone実行  
✓ GitHub Actions workflow の配置 (`.github/workflows/deploy-gas.yml`)  
✓ git init / develop ブランチ作成  
✓ リモートリポジトリ接続  
✓ ファイル登録・初回コミット  
✓ develop / main ブランチ をGitHubにプッシュ  
✓ GitHub Environments の secret 登録  

完了後、フォルダは開発準備完了状態です。

### GitHub Actions workflow について

`artifacts/.github/workflows/deploy-gas.yml` は初期化時に新規プロジェクトへコピーされます。  
この workflow は `develop` / `main` への push と手動実行 (`workflow_dispatch`) に対応しており、`clasp` を使った Apps Script の push / version / deploy を行います。

配置先がプロジェクト直下ではなく、必ず `.github/workflows/deploy-gas.yml` になっていることを確認してください。

- `develop` への push は `production` environment の secrets を使った `clasp push` のみを実行します。
- `main` への push は `production` environment の secrets を使って `clasp push` に加え `clasp deploy` まで実行します。
- 追加 environment は `workflow_dispatch` で明示指定して deploy します。
- `main` 向け PR 作成時に、開発環境確認 URL を PR コメントとして自動投稿します。

PR コメントに表示する URL は以下の優先順位です。

1. Repository Variables の `GAS_DEV_CHECK_URL`
2. `production` environment の `CLASP_SCRIPT_ID` から生成した Apps Script エディタ URL

`GAS_DEV_CHECK_URL` の設定を推奨します。

CI/CD の詳細な流れは [deploy-gas-cicd.md](deploy-gas-cicd.md) を参照してください。

### Environment secret について

初期化スクリプトは `production` environment をデフォルトで登録し、必要に応じて追加 environment もまとめて登録できます。

- `CLASP_CREDENTIALS_JSON` : ローカルの `~/.clasprc.json` を元に登録
- `CLASP_SCRIPT_ID` : `clasp` の script ID
- `CLASP_DEPLOYMENT_ID` : 任意。既存 deployment を更新する場合に利用

Environment secret は後から次のスクリプトでも登録できます。

```powershell
register-gas-environment-secrets.bat
register-gas-environment-secrets.ps1
```

## トラブルシューティング

### エラー: `clasp` コマンドが見つからない

```powershell
npm install -g @google/clasp
```

を実行してインストール完了後、再度スクリプトを実行してください。

### エラー: `git` コマンドが見つからない

[Git for Windows](https://git-scm.com/download/win) をインストールしてください。

### エラー: GitHub認証失敗

以下を確認：

- Personal Access Token（PAT）が正しく生成されているか
- PAT に `repo` スコープが付与されているか
- トークンが有効期限内か

詳細は [GitHub Docs - Personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) を参照してください。

### エラー: GitHub CLI 認証失敗

以下を確認：

- `gh` コマンドがインストールされているか
- `gh auth login` が完了しているか
- 対象 repository に対する権限があるか

### エラー: `clasp clone` 失敗

以下を確認：

- Apps Script スクリプト ID が正しいか
- `clasp login` で認証済みか
- アクセス権限があるか

### `clasp clone completed` と表示されるが `.gs` などのファイルがない

以下を確認してください。

- 入力した Script ID が対象プロジェクトのものか
- その Script への閲覧権限があるか
- 対象プロジェクトが実際にソースファイルを持っているか

最新版スクリプトでは `clasp clone` 後に `clasp pull` と `appsscript.json` の存在チェックを行うため、異常時は明示的に停止します。

`Invalid script ID.` が出た場合は clone を失敗として停止します。Script ID の再確認と、対象プロジェクトへのアクセス権確認を行ってください。

### エラー: `git checkout -b develop` 実行時の `NativeCommandError`

既存フォルダを再利用した場合に、`develop` ブランチが既に存在していると発生することがあります。

- 新しい空フォルダで再実行する
- または既存フォルダの `.git` を削除してから再実行する

### エラー: `remote: Repository not found.`

以下を確認してください。

- 入力したリポジトリ URL が正しいか
- 対象リポジトリが存在するか
- private リポジトリの場合、`git` の認証情報にアクセス権があるか

`init-gas-project.ps1` はリモート到達確認を行うため、URL 入力時点で失敗原因を早期に検出できます。

### `git push` 時に赤文字で `NativeCommandError` が出るが branch 作成は成功している

PowerShell が `git` の標準エラー出力をエラー表示する場合があります。以下が表示されていれば push 自体は成功です。

- `branch 'develop' set up to track 'origin/develop'`
- `[new branch] develop -> develop`
- `[new branch] main -> main`

最新版スクリプトでは `git push` を `cmd /c` 経由で実行するため、この誤検知表示を回避します。

## スクリプト修正

スクリプト内容を編集する場合は、`init-gas-project.ps1` と `register-gas-environment-secrets.ps1` を任意のテキストエディタで開いて修正してください。

## 補足

- `artifacts/` は新規プロジェクトへ配布するテンプレート資材置き場です。
- `artifacts/.github/workflows/deploy-gas.yml` に GitHub Actions 用の CI/CD 定義を格納しています。
- `register-gas-environment-secrets.ps1` は、初期化後に environment secret を再登録したい場合にも使えます。

