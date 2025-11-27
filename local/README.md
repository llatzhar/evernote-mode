# Evernote Local Cache Editor

## 概要

evernote-modeとは独立して動作する、ローカルキャッシュデータを直接読み書きするRubyコンソールアプリケーションです。
Evernoteサービスに接続せずに、ローカルに保存されたノート、ノートブック、タグ、保存された検索などを操作できます。

## キャッシュデータの場所

- 開発環境: `C:\gits\.evernote-mode\`
- 本番環境: `~/.evernote-mode/`

## データベース構造

### GDBMファイル
- `notebook` - ノートブック情報
- `note` - ノートメタデータ
- `tag` - タグ情報
- `saved_search` - 保存された検索
- `sync` - 同期情報（最終同期時刻、USN）

### コンテンツディレクトリ
- `contents/` - ノートの本文（GUID別のファイル）

### その他
- `lock` - トランザクション用ロックファイル

## evernote-mode.elから抽出した必要機能

### 1. ノート操作

#### 読み取り機能
- **ノート一覧の取得** (`evernote-open-note`)
  - ノートブック別フィルタリング
  - タグ別フィルタリング
  - 検索クエリによるフィルタリング
  - ノート属性（GUID, タイトル, 更新日時, タグ, ノートブック）の表示

- **ノート内容の取得** (`enh-base-open-note-common`)
  - GUID指定でノート取得
  - 編集モード（TEXT/XHTML）の判定
  - コンテンツのフォーマット（ENMLからプレーンテキストへの変換）

#### 書き込み機能
- **ノート作成** (`evernote-create-note`)
  - タイトルの設定
  - ノートブックの指定
  - タグの設定
  - 編集モード（TEXT/XHTML）の選択

- **ノート更新** (`evernote-save-note`)
  - タイトル変更
  - 内容変更
  - タグ追加/削除
  - ノートブック移動
  - 編集モード変更

- **ノート削除** (`evernote-delete-note`)

### 2. ノートブック操作

- **ノートブック一覧** (`evernote-browsing-list-notebooks`)
  - 全ノートブック取得
  - デフォルトノートブックの確認

- **ノートブック作成** (`evernote-create-notebook`)
  - 名前設定
  - デフォルトノートブック指定

- **ノートブック編集** (`evernote-edit-notebook`)
  - 名前変更
  - デフォルト設定変更

### 3. タグ操作

- **タグ一覧** (`evernote-browsing-list-tags`)
  - 全タグ取得
  - 階層構造の表示（親タグ関係）

- **タグ編集** (`evernote-edit-tags`)
  - ノートへのタグ追加
  - ノートからタグ削除

### 4. 保存された検索

- **検索一覧** (`evernote-browsing-list-searches`)
  - 保存された検索の一覧表示

- **検索実行** (`evernote-do-saved-search`)
  - 保存されたクエリでノート検索

- **検索作成** (`evernote-create-search`)
  - 名前とクエリの保存

- **検索編集** (`evernote-edit-search`)
  - 名前・クエリの変更

### 5. ブラウジング機能

- **インタラクティブブラウザ** (`evernote-browser`)
  - ページ履歴管理（前へ/次へ）
  - ノート一覧からノート詳細へのナビゲーション
  - ノートブック/タグ/検索一覧の表示

### 6. キャッシュ管理

- **キャッシュ読み取り**
  - オフライン時のノート閲覧
  - メタデータのローカル検索

- **キャッシュクリア** (`enh-clear-onmem-cache`)
  - メモリ内キャッシュの削除

## 必要なコマンド仕様

### 基本コマンド

```bash
# ノート一覧
enlocal list-notes [--notebook GUID] [--tag GUID] [--query TEXT]

# ノート表示
enlocal show-note GUID [--format text|xhtml]

# ノート作成
enlocal create-note --title TITLE [--notebook GUID] [--tags TAG1,TAG2] [--content-file FILE] [--edit-mode text|xhtml]

# ノート更新
enlocal update-note GUID [--title TITLE] [--notebook GUID] [--tags TAG1,TAG2] [--content-file FILE]

# ノート削除
enlocal delete-note GUID

# ノートブック一覧
enlocal list-notebooks

# ノートブック作成
enlocal create-notebook --name NAME [--default]

# ノートブック更新
enlocal update-notebook GUID --name NAME [--default]

# タグ一覧
enlocal list-tags [--tree]

# 保存された検索一覧
enlocal list-searches

# 検索実行
enlocal search QUERY

# 保存された検索実行
enlocal do-saved-search GUID

# キャッシュ統計
enlocal stats

# エクスポート
enlocal export-note GUID --output FILE [--format text|xhtml|enml]
enlocal export-all --output-dir DIR
```

### インタラクティブモード

```bash
enlocal interactive
```

対話的なREPLモードで以下を提供：
- タブ補完（ノート名、タグ名など）
- コマンド履歴
- 検索結果の絞り込み
- ページネーション

## 技術仕様

### 重要：EDAMとENMLへの対応が必須

ローカルキャッシュを操作する場合でも、以下の理由でEDAMとENMLの仕様を完全に理解・実装する必要があります：

1. **キャッシュデータはEDAM形式**: GDBMに保存されているデータはすべてEDAM Thriftオブジェクトのシリアライズ形式
2. **ノート内容はENML形式**: `contents/`ディレクトリ内のファイルはENML（Evernote Markup Language）形式
3. **編集時の整合性**: ノートを編集する場合、ENML検証とフォーマット変換が必要

### データアクセス層

`enclient.rb`の`DBManager`クラスと`DBUtils`クラスを参考に実装：

```ruby
class LocalCacheManager
  # DBManager相当の機能
  - GDBM操作（notebook, note, tag, saved_search）
  - トランザクション管理（File::LOCK_EX使用）
  - コンテンツファイルI/O
  - ロック状態の確認（evernote-mode同期中の検出）
  
  # DBUtils相当の機能  
  - get_all_notebooks(dm)
  - get_all_tags(dm)
  - get_all_searches(dm)
  - get_note(dm, guid)
  - set_note_and_content(dm, note, content)
  - get_last_sync_and_usn(dm) # 同期状態の確認
end
```

### EDAMオブジェクトのシリアライズ

`enclient.rb`では独自のシリアライズ形式を実装しています：

**格納形式**: カンマ区切りのフィールド（`field=value,field=value,...`）

**フィールドタイプ**:
- `:field_type_int` - 整数値
- `:field_type_bool` - 真偽値（`true`/`false`）
- `:field_type_string` - 文字列（ASCII）
- `:field_type_base64` - Base64エンコード文字列（UTF-8タイトル、タグ名など）
- `:field_type_string_array` - パイプ区切り文字列配列
- `:field_type_base64_array` - Base64エンコード文字列配列
- `:field_type_timestamp` - UNIXタイムスタンプ（ミリ秒）
- `:field_type_object` - ネストされたオブジェクト（Base64エンコード）

**シリアライズされるEDAMオブジェクト**:

```ruby
# Notebook
{
  :guid => :field_type_string,
  :name => :field_type_base64,          # Base64でエンコード！
  :updateSequenceNum => :field_type_int,
  :defaultNotebook => :field_type_bool,
  :serviceCreated => :field_type_timestamp,
  :serviceUpdated => :field_type_timestamp
}

# Note（拡張フィールド含む）
{
  :guid => :field_type_string,
  :title => :field_type_base64,         # Base64でエンコード！
  :created => :field_type_timestamp,
  :updated => :field_type_timestamp,
  :updateSequenceNum => :field_type_int,
  :notebookGuid => :field_type_string,
  :tagGuids => :field_type_string_array,
  :tagNames => :field_type_base64_array, # Base64でエンコード！
  :editMode => :field_type_string,       # "TEXT" or "XHTML"（独自拡張）
  :attributes => :field_type_object,     # NoteAttributes
  :resources => :field_type_string_array,
  :contentFile => :field_type_base64     # コンテンツファイルパス（独自拡張）
}

# NoteAttributes
{
  :subjectDate => :field_type_timestamp,
  :sourceApplication => :field_type_base64, # 編集モード判定に使用
  :author => :field_type_string,
  # ... その他の属性
}

# Tag
{
  :guid => :field_type_string,
  :name => :field_type_base64,           # Base64でエンコード！
  :parentGuid => :field_type_string,     # 階層構造
  :updateSequenceNum => :field_type_int
}

# SavedSearch
{
  :guid => :field_type_string,
  :name => :field_type_base64,           # Base64でエンコード！
  :query => :field_type_base64,          # Base64でエンコード！
  :format => :field_type_int,
  :updateSequenceNum => :field_type_int
}
```

**重要な独自拡張フィールド**:
- `editMode` (Note): "TEXT"または"XHTML" - `sourceApplication`から判定
- `contentFile` (Note): コンテンツファイルの絶対パス

### ENMLフォーマッター

**ENML基本構造**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>
  <!-- コンテンツ -->
</en-note>
```

**編集モードによる処理の違い**:

1. **TEXTモード** (`editMode == "TEXT"`):
   - 保存時: プレーンテキスト → ENML変換
     - HTMLエスケープ (`CGI.escapeHTML`)
     - スペース → `&nbsp;`
     - 改行 → `<br clear="none"/>`
   - 読み取り時: ENML → プレーンテキスト変換
     - `<br.*/>` → 改行
     - `&nbsp;` → スペース
     - HTMLアンエスケープ (`CGI.unescapeHTML`)

2. **XHTMLモード** (`editMode == "XHTML"`):
   - 保存時: XHTML → そのままENMLとして保存
   - 読み取り時: ENML → そのまま返す

**編集モードの判定**:
```ruby
# sourceApplicationから判定
"emacs-enclient {:version => 0.41, :editmode => "TEXT"}"
"emacs-enclient {:version => 0.41, :editmode => "XHTML"}"
```

### フォーマット変換の実装

```ruby
# TEXT → ENML変換
def to_enml_from_text(content)
  content = CGI.escapeHTML(content)
  content.gsub!(/\ /, '&nbsp;')
  content.gsub!(/(?:\r\n)|\n|\r/, '<br clear="none"/>')
  '<?xml version="1.0" encoding="UTF-8"?>' +
  '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">' +
  '<en-note>' + content + '</en-note>'
end

# ENML → TEXT変換
def to_text_from_enml(enml)
  enml =~ /<en-note[^>]*>(.*)<\/en-note>/m
  content = $1
  content.gsub!(/<br.*?\/>/m, "\n")
  content.gsub!(/&nbsp;/m, " ")
  CGI.unescapeHTML(content)
end
```

### データ整合性の維持

**updateSequenceNum (USN)の重要性**:
- 各オブジェクトのバージョン管理に使用
- ローカル編集時はUSNを変更しない（同期時に競合検出のため）
- 同期情報（`sync`データベース）に最終同期USNを保持

### エラーハンドリング

`enclient.rb`のエラーコードに準拠：
- `ERROR_CODE_OK = 0`
- `ERROR_CODE_NOT_FOUND = 100`
- `ERROR_CODE_UNEXPECTED = 101`

## 実装状況

### ✅ Phase 1: 基本読み取り機能（実装完了）

実装済みの機能：

1. **EDAMデシリアライズ** (`lib/enlocal.rb`)
   - Base64デコード（タイトル、タグ名、ノートブック名）
   - カンマ区切りフィールドのパース
   - Notebook, Note, Tag, SavedSearch オブジェクトの復元

2. **ENML → プレーンテキスト変換** (`ENMLFormatter`)
   - `<br/>` → 改行
   - `&nbsp;` → スペース
   - HTMLアンエスケープ
   - 編集モード判定（TEXT/XHTML）

3. **データベース操作** (`DBManager`)
   - GDBM読み取り（読み取り専用）
   - トランザクション管理（共有ロック）
   - ロック状態確認（evernote-mode同期中検出）
   - ノートコンテンツファイル読み取り

4. **高レベルAPI** (`CacheReader`)
   - ノート一覧取得（ノートブック/タグフィルタ対応）
   - ノートブック一覧取得
   - タグ一覧取得（階層構造構築）
   - 保存された検索一覧取得
   - ノート詳細取得
   - タイトル検索（部分一致）
   - 同期情報取得
   - キャッシュ統計

5. **コマンドラインツール** (`bin/enlocal`)
   - `list-notebooks` - ノートブック一覧
   - `list-tags` - タグ一覧（フラット/ツリー表示）
   - `list-searches` - 保存された検索一覧
   - `list-notes` - ノート一覧（フィルタ/制限対応）
   - `show-note` - ノート詳細表示（TEXT/ENML形式）
   - `search` - タイトル検索
   - `stats` - キャッシュ統計

6. **テスト** (`test/test_enlocal.rb`)
   - ENMLフォーマッタのテスト
   - シリアライズ/デシリアライズのテスト
   - 全テスト通過確認済み

### ✅ エクスポート機能（実装完了）

**Phase 2より先行実装**

実装済みの機能：

1. **ヒューマンリーダブル形式** (`NoteExporter`)
   - YAML frontmatter + Markdown形式
   - ENML/EDAM非依存
   - Git管理可能
   - 他ツール（Obsidian, Joplin等）と互換性

2. **エクスポートオプション**
   - ディレクトリ構造: `flat`, `notebook`, `date`, `tag`
   - ファイル名形式: `guid`, `title`, `timestamp-title`, `guid-title`
   - メタデータインデックス（JSON）生成

3. **エクスポートコマンド**
   - `export-note GUID` - 単一ノートエクスポート
   - `export-notebook GUID` - ノートブック単位エクスポート
   - `export-all` - 全ノートエクスポート

4. **フォーマット詳細** (`EXPORT_FORMAT.md`)
   - YAML frontmatter仕様
   - ディレクトリ構造オプション
   - 再インポート設計
   - 他ツールとの連携方法

### 使用例

```bash
# 単一ノートをエクスポート
ruby bin/enlocal --cache-dir C:\gits\.evernote-mode \
  export-note <GUID> --output note.md

# 全ノートをノートブック別にエクスポート
ruby bin/enlocal --cache-dir C:\gits\.evernote-mode \
  export-all --output export \
  --structure notebook \
  --filename timestamp-title \
  --index

# エクスポート結果
export/
├── index.json
├── ノートブック1/
│   ├── 20250120_ノート1.md
│   └── 20250121_ノート2.md
└── ノートブック2/
    └── 20250115_ノート3.md
```

### エクスポート形式の特徴

```yaml
---
title: ノートタイトル
guid: e3bdd511-6dac-4597-86d1-be46d0b006e9
created: "2025-10-20T08:47:24+09:00"
updated: "2025-10-20T08:47:49+09:00"
notebook: "ノートブック名"
notebook_guid: be2610e6-3f79-4be4-ab47-67df5ef56412
tags:
  - タグ1
  - タグ2
edit_mode: TEXT
usn: 13576
---

# ノートタイトル

ノートの本文...
```

**利点**:
- 人間が読める・編集できる
- Git等でバージョン管理可能
- grep等で検索可能
- Obsidian, Joplinなどで利用可能
- 静的サイトジェネレータ（Jekyll, Hugo）対応

### ファイル構成

```
local/
├── README.md                 # プロジェクト概要
├── INSTALL.md                # インストール手順
├── USAGE.md                  # 使用例
├── EXPORT_FORMAT.md          # エクスポート形式仕様
├── PREFETCH.md               # コンテンツキャッシュ作成ガイド
├── bin/
│   ├── enlocal              # CLIツール（ローカル操作）
│   └── enprefetch.rb        # コンテンツ取得ツール（サービス接続）
├── lib/
│   └── enlocal.rb           # コアライブラリ（実装完了）
└── test/
    └── test_enlocal.rb      # ユニットテスト（実装完了）
```

### 動作確認方法

```bash
# テスト実行
cd local
ruby test/test_enlocal.rb

# ヘルプ表示
ruby bin/enlocal --help

# 開発キャッシュで統計表示（GDBM必要）
ruby bin/enlocal --cache-dir C:\gits\.evernote-mode stats

# コンテンツキャッシュ分析
ruby bin/enprefetch.rb --cache-dir C:\gits\.evernote-mode analyze

# エクスポートテスト
ruby bin/enlocal --cache-dir C:\gits\.evernote-mode \
  export-all --output test_export --structure notebook --index
```

## 実装状況

### Phase 1: 基本読み取り機能（完了✅）

すべての機能が実装され、テスト済みです：

- ✅ ノート一覧
- ✅ ノートブック一覧
- ✅ タグ一覧（階層構造対応）
- ✅ 保存された検索一覧
- ✅ 個別ノート表示（テキスト/ENML形式）
- ✅ タイトル検索
- ✅ 統計情報

### Prefetch機能（完了✅）

サービスからコンテンツを取得してキャッシュを完全化：

- ✅ キャッシュ分析（欠落ノート特定）
- ✅ 全ノート一括取得
- ✅ 個別ノート取得
- ✅ キャッシュ検証
- ✅ ドライラン・制限オプション
- ✅ レート制限対応

詳細: [PREFETCH.md](PREFETCH.md)

### Export機能（完了✅）

人間が読める形式でのエクスポート：

- ✅ YAML + Markdown形式
- ✅ 4種類のディレクトリ構造（フラット/ノートブック/日付/タグ）
- ✅ 4種類のファイル名形式（GUID/タイトル/タイムスタンプ付き/複合）
- ✅ メタデータインデックス（JSON）
- ✅ 単一ノート・ノートブック・全体エクスポート

詳細: [EXPORT_FORMAT.md](EXPORT_FORMAT.md)

### 次のステップ: Phase 2（未実装）

Phase 2では書き込み機能を実装予定：

### Phase 1: 基本読み取り機能（EDAM/ENMLデコードのみ）
1. GDBMからのデータ読み取り
2. Base64デコード（タイトル、タグ名、ノートブック名）
3. EDAMシリアライズからのデシリアライズ
4. ENML → プレーンテキスト変換
5. ノート一覧取得
6. ノート詳細表示
7. ノートブック一覧
8. タグ一覧（階層構造の表示）
9. 検索機能（ローカルフィルタリング）

### Phase 2: 基本書き込み機能（EDAM/ENMLエンコード対応）
1. Base64エンコード
2. EDAMシリアライズへのシリアライズ
3. プレーンテキスト → ENML変換
4. ノート作成（editMode設定、sourceApplication設定）
5. ノート更新（タイトル、内容、USN管理）
6. タグ追加/削除（tagGuids, tagNamesの同期）
7. ノートブック作成（defaultNotebookの排他制御）

### Phase 3: 高度な機能
1. インタラクティブモード
2. エクスポート機能（ENML/TEXT/XHTML）
3. バッチ操作
4. キャッシュ統計・検証（USN整合性チェック）
5. 同期状態の確認と警告表示

## 制約事項と注意点

### データ形式の制約

- **EDAMシリアライズ形式の理解が必須**: GDBMから読み書きするにはシリアライズ/デシリアライズの実装が必要
- **Base64エンコーディング**: タイトル、タグ名、ノートブック名、検索クエリはすべてBase64エンコード
- **ENML必須**: ノートコンテンツは必ずENML形式（XMLとして正しい形式が必要）
- **編集モードの保持**: TEXTとXHTMLの区別を維持する必要あり

### 同期との競合

- **読み取り専用が推奨**: キャッシュを直接編集すると同期時に競合が発生する可能性
- **同期中の使用制限**: evernote-modeの同期処理中は使用不可（lockファイルで`File::LOCK_EX`による排他制御）
- **USNの管理**: updateSequenceNumを不用意に変更すると同期が破綻
- **フルシンク時の危険性**: フルシンク中（`during_full_sync?`）はデータベースがクリアされる可能性

### ENML処理の制約

- **完全なENML検証は困難**: DTD検証まで行うのは複雑
- **基本構造の維持**: `<?xml...>`, `<!DOCTYPE...>`, `<en-note>...</en-note>`は必須
- **リソース未対応**: 画像などのリソース（`resources`フィールド）は未実装
- **オフライン専用**: Evernoteサービスとの通信機能は持たない

### 推奨される安全な使い方

1. **読み取り専用で使用**: 検索、一覧表示、エクスポートなど
2. **バックアップ作成**: 編集前にキャッシュディレクトリ全体をバックアップ
3. **ロック確認**: トランザクション開始前にlockファイルの状態を確認
4. **同期状態の確認**: `get_last_sync_and_usn`で最終同期時刻を確認

## 使用例

### ノートの検索と表示

```bash
# タイトルに"Meeting"を含むノートを検索
enlocal search "intitle:Meeting"

# 特定ノートブックのノートを一覧表示
enlocal list-notes --notebook <GUID>

# ノート詳細をプレーンテキストで表示
enlocal show-note <GUID> --format text
```

### ノートの編集

```bash
# 新規ノート作成（エディタで編集）
enlocal create-note --title "New Note" --notebook <GUID>

# 既存ノートの内容を更新
enlocal update-note <GUID> --content-file updated.txt

# タグを追加
enlocal update-note <GUID> --tags "work,important"
```

### バックアップ・エクスポート

```bash
# 全ノートをエクスポート
enlocal export-all --output-dir ~/evernote-backup

# 特定ノートをテキストファイルにエクスポート
enlocal export-note <GUID> --output note.txt --format text
```

## 開発ガイドライン

### ディレクトリ構造

```
local/
├── README.md                 # このファイル
├── bin/
│   └── enlocal              # メインコマンド
├── lib/
│   ├── enlocal.rb           # メインモジュール
│   ├── cache_manager.rb     # キャッシュアクセス
│   ├── formatter.rb         # ENML変換
│   ├── commands/            # コマンド実装
│   │   ├── list.rb
│   │   ├── show.rb
│   │   ├── create.rb
│   │   └── ...
│   └── interactive/         # インタラクティブモード
│       └── repl.rb
└── test/
    └── ...
```

### 依存ライブラリ

**必須**:
- `gdbm` - データベースアクセス
- `base64` - タイトル・タグ名などのエンコード/デコード
- `cgi` - HTMLエスケープ/アンエスケープ（ENML処理）

**任意（機能拡張用）**:
- `evernote_oauth` - EDAM Thriftオブジェクト定義の参照用
- `thor` or `optparse` - CLIフレームワーク
- `readline` - インタラクティブモード

**注意**: `evernote_oauth` gemは必須ではありません。`enclient.rb`の`Serializable`モジュールを参考に、独自のシリアライズ/デシリアライズを実装できます。

### テスト

開発用キャッシュ（`C:\gits\.evernote-mode\`）を使用してテスト。
本番データへの影響を避けるため、読み取り専用モードでの開発を推奨。

## 参考

- `ruby/bin/enclient.rb` - Evernote APIクライアント実装
- `evernote-mode.el` - Emacs統合機能
- Evernote EDAM API - データモデル仕様
