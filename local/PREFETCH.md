# Evernote Prefetch - コンテンツキャッシュ作成ツール

## 概要

`enprefetch.rb`は、Evernoteサービスからノートのコンテンツを取得してローカルキャッシュに保存するツールです。

### 背景

evernote-modeでは、ノートを実際に開くまでコンテンツはキャッシュされません。
メタデータ（タイトル、タグ、ノートブック等）はキャッシュされますが、ノート本文は`contents/`フォルダに保存されません。

これにより、以下の問題が発生します：

1. **エクスポート時の問題**: 未読のノートはエクスポートできない
2. **検索の限界**: ノート本文を検索できない
3. **バックアップ不完全**: メタデータのみでコンテンツが欠落

`enprefetch.rb`は、すべてのノートのコンテンツを一括でキャッシュに保存することで、これらの問題を解決します。

## 前提条件

### 必要なGem

```powershell
gem install gdbm
gem install oauth
gem install evernote_oauth
```

**注意**: GDBMのインストール方法は[INSTALL.md](INSTALL.md)を参照してください。

### Developer Token

Evernote Developer Tokenが必要です。

**取得方法**:
1. https://www.evernote.com/api/DeveloperToken.action にアクセス
2. Evernoteアカウントでログイン
3. Developer Tokenを生成
4. トークンを安全に保存

### 依存関係

- `enclient.rb`（`ruby/bin/enclient.rb`が必要）
- `gdbm` gem（キャッシュアクセス用）
- `oauth` gem（Evernote OAuth認証用）
- `evernote_oauth` gem（Evernote API用）

**注意**: これらのgemがインストールされていない場合、enprefetch.rbは動作しません。
エラーメッセージを確認して必要なgemをインストールしてください。

## 使い方

### 基本コマンド

```bash
# 環境変数でトークンを設定
$env:EVERNOTE_TOKEN='your-developer-token-here'

# キャッシュ分析
ruby local/bin/enprefetch.rb analyze

# 全ノートのコンテンツを取得（ドライラン）
ruby local/bin/enprefetch.rb fetch-all --dry-run

# 全ノートのコンテンツを実際に取得
ruby local/bin/enprefetch.rb fetch-all

# キャッシュの整合性を検証
ruby local/bin/enprefetch.rb verify
```

### コマンド詳細

#### analyze - キャッシュ分析

キャッシュの状態を分析し、コンテンツが欠落しているノートを特定します。

```bash
ruby local/bin/enprefetch.rb analyze
```

**出力例**:
```
Analyzing cache...

Cache Analysis:
  Total notes: 1527
  Cached: 245 (16.0%)
  Missing: 1282 (84.0%)
```

#### fetch-all - 全ノート取得

コンテンツが欠落しているすべてのノートをサービスから取得します。

```bash
# ドライラン（実際には取得しない）
ruby local/bin/enprefetch.rb fetch-all --dry-run

# 実際に取得
ruby local/bin/enprefetch.rb fetch-all

# 件数を制限（テスト用）
ruby local/bin/enprefetch.rb fetch-all --limit 10
```

**オプション**:
- `--dry-run`: 実際には取得せず、何が取得されるかを表示
- `--limit N`: 取得するノート数を制限

**動作**:
1. キャッシュを分析して欠落ノートを特定
2. 各ノートをサービスから取得（API呼び出し）
3. 編集モード（TEXT/XHTML）に応じてフォーマット変換
4. `contents/`フォルダに保存
5. 10件ごとに進捗表示

**注意**:
- 大量のノートがある場合、完了まで時間がかかります
- レート制限を避けるため、取得間隔に0.1秒のスリープを挿入
- エラーが発生したノートはスキップして続行

#### fetch-note - 個別ノート取得

特定のノートのコンテンツを取得します。

```bash
ruby local/bin/enprefetch.rb fetch-note <NOTE_GUID>
```

**例**:
```bash
ruby local/bin/enprefetch.rb fetch-note e3bdd511-6dac-4597-86d1-be46d0b006e9
```

#### verify - キャッシュ検証

キャッシュの整合性を検証します。

```bash
ruby local/bin/enprefetch.rb verify
```

**チェック項目**:
- コンテンツファイルの存在
- ファイルの読み取り可否
- ファイルが空でないか

**出力例**:
```
Verification Results:
  Total notes: 1527
  Verified: 1520 (99.5%)
  Missing: 5 (0.3%)
  Corrupted: 2 (0.1%)
```

## オプション

### --cache-dir DIR

キャッシュディレクトリを指定します。

```bash
ruby local/bin/enprefetch.rb --cache-dir C:\gits\.evernote-mode analyze
```

デフォルト: `~/.evernote-mode`

### --token TOKEN

Developer Tokenを直接指定します。

```bash
ruby local/bin/enprefetch.rb --token YOUR_TOKEN analyze
```

環境変数`EVERNOTE_TOKEN`が設定されていれば省略可能。

### --dry-run

実際にはデータを取得せず、何が実行されるかのみ表示します。

```bash
ruby local/bin/enprefetch.rb fetch-all --dry-run
```

### --limit N

取得するノート数を制限します（テスト用）。

```bash
ruby local/bin/enprefetch.rb fetch-all --limit 10
```

## 典型的な使用フロー

### 初回セットアップ

```bash
# 1. Developer Tokenを設定
$env:EVERNOTE_TOKEN='your-token-here'

# 2. キャッシュの状態を確認
ruby local/bin/enprefetch.rb analyze

# 3. ドライランで確認
ruby local/bin/enprefetch.rb fetch-all --dry-run --limit 5

# 4. 少量でテスト
ruby local/bin/enprefetch.rb fetch-all --limit 5

# 5. 問題なければ全件取得
ruby local/bin/enprefetch.rb fetch-all
```

### 定期メンテナンス

同期後、新しいノートのコンテンツを取得：

```bash
# 分析して欠落を確認
ruby local/bin/enprefetch.rb analyze

# 欠落分のみ取得
ruby local/bin/enprefetch.rb fetch-all
```

### エクスポート前

```bash
# 1. すべてのコンテンツを取得
ruby local/bin/enprefetch.rb fetch-all

# 2. 検証
ruby local/bin/enprefetch.rb verify

# 3. エクスポート
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode \
  export-all --output export --structure notebook --index
```

## トラブルシューティング

### "Developer token required"

```bash
# トークンを環境変数で設定
$env:EVERNOTE_TOKEN='your-token-here'

# または、直接指定
ruby local/bin/enprefetch.rb --token YOUR_TOKEN analyze
```

### "Cannot load enclient.rb"

`enclient.rb`が正しい場所にあることを確認：
```
ruby/bin/enclient.rb
```

### "Cache is locked"

evernote-modeが同期中です。同期完了を待ってから実行してください。

### レート制限エラー

Evernote APIのレート制限に達した場合：
1. しばらく待つ（1時間程度）
2. `--limit`オプションで少しずつ取得

### 認証エラー

Developer Tokenの有効期限を確認：
- https://www.evernote.com/api/DeveloperToken.action
- 期限切れの場合は再生成

## パフォーマンス

### 取得時間の目安

- 1ノートあたり約0.1〜0.2秒
- 1000ノート: 約2〜3分
- 10000ノート: 約20〜30分

### ネットワーク使用量

- 1ノートあたり約1〜10KB（ノートサイズによる）
- 画像などのリソースは含まない（メタデータのみ）

## セキュリティ

### Developer Tokenの保護

Developer Tokenは完全なアカウントアクセス権を持ちます：

1. **環境変数で管理**:
   ```powershell
   $env:EVERNOTE_TOKEN='your-token-here'
   ```

2. **ファイルに保存しない**:
   - Git等でコミットしない
   - スクリプトにハードコードしない

3. **定期的に再生成**:
   - セキュリティのため定期的に再生成を推奨

## 制限事項

1. **リソース未対応**: 画像などの添付ファイルは取得しません
2. **レート制限**: Evernote APIのレート制限に従います
3. **ネットワーク必須**: オフラインでは動作しません

## enlocal との連携

```bash
# 1. コンテンツを取得
ruby local/bin/enprefetch.rb fetch-all

# 2. ローカルで読み取り
ruby local/bin/enlocal list-notes --limit 10

# 3. エクスポート
ruby local/bin/enlocal export-all --output export --structure notebook
```

## 開発者向け

### デバッグモード

```bash
$env:DEBUG='1'
ruby local/bin/enprefetch.rb fetch-all
```

エラー発生時に詳細なスタックトレースが表示されます。

### コード構造

```ruby
EnPrefetch::Prefetcher
├── authenticate(token)      # 認証
├── analyze_cache()          # キャッシュ分析
├── fetch_all_missing()      # 全件取得
├── fetch_note(guid)         # 個別取得
└── verify_cache()           # 検証
```

### 拡張

`enclient.rb`のインフラを再利用しているため、以下が可能：
- トランザクション管理
- EDAM型のシリアライズ
- ENML変換
- データベース操作
