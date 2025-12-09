# Evernote Local Cache Export Format

## 概要

ENMLやEDAM形式に依存しない、ヒューマンリーダブルなエクスポート形式を定義します。

## フォーマット仕様

### 1ノート = 1ファイル形式

各ノートは個別のMarkdownファイルとしてエクスポートされます。

### ファイル名

```
{guid}.md
または
{sanitized_title}.md
または
{timestamp}_{sanitized_title}.md
```

### ファイル構造

```markdown
---
title: ノートのタイトル
guid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
created: "2024-01-15T10:30:00+09:00"
updated: "2024-01-20T15:45:00+09:00"
notebook: ノートブック名
notebook_guid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
tags: [タグ1, タグ2, タグ3]
tag_guids:
  - xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  - xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
source: emacs
author: ユーザー名
edit_mode: TEXT
---

# ノートのタイトル

ノートの本文がここに入ります。
改行やフォーマットはそのまま維持されます。

## セクション

- リスト項目1
- リスト項目2

コードブロックなども表現可能。
```

### Foam/Obsidian互換性

`tags`フィールドは、VS Code拡張機能のFoamやObsidianと互換性のある
インライン配列形式 `tags: [tag1, tag2]` で出力されます。

これにより：
- Foam Tag Explorerでタグが認識される
- Obsidianのタグ機能と連携
- 標準的なYAML配列として他ツールでも読み取り可能

### フィールド詳細

#### YAML Frontmatter (メタデータ)

**必須フィールド**:
- `title`: ノートタイトル
- `guid`: ノートGUID
- `created`: 作成日時（ISO 8601形式）
- `updated`: 更新日時（ISO 8601形式）

**任意フィールド**:
- `notebook`: ノートブック名（人間が読める）
- `notebook_guid`: ノートブックGUID
- `tags`: タグのリスト（配列）
- `tag_guids`: タグGUIDのリスト（配列）
- `source`: ソースアプリケーション
- `author`: 著者
- `edit_mode`: 編集モード（TEXT/XHTML）
- `source_url`: ソースURL
- `reminder_time`: リマインダー時刻
- `latitude`: 緯度
- `longitude`: 経度
- `usn`: 更新シーケンス番号

#### 本文

YAML frontmatterの後、`---`区切りの後に本文が続きます。

**TEXTモード**:
- ENML → プレーンテキスト変換
- Markdown記法で表現
- そのまま人間が読める

**XHTMLモード**:
- ENMLのXHTML部分を抽出
- 可能な限りMarkdownに変換
- または、HTMLコードブロックとして保存

## エクスポートオプション

### ディレクトリ構造オプション

#### Flat (デフォルト)
```
export/
├── note1.md
├── note2.md
└── note3.md
```

#### By Notebook
```
export/
├── ノートブック1/
│   ├── note1.md
│   └── note2.md
└── ノートブック2/
    └── note3.md
```

#### By Date
```
export/
├── 2024/
│   ├── 01/
│   │   └── note1.md
│   └── 02/
│       └── note2.md
└── 2025/
    └── 01/
        └── note3.md
```

#### By Tag
```
export/
├── タグ1/
│   ├── note1.md
│   └── note2.md
└── タグ2/
    └── note3.md
```

### ファイル名オプション

- `guid`: GUID のみ (`e3bdd511-xxxx.md`)
- `title`: タイトルのみ (`平日は毎日.md`)
- `timestamp-title`: タイムスタンプ + タイトル (`20250120_平日は毎日.md`)
- `guid-title`: GUID + タイトル (`e3bdd511_平日は毎日.md`)

### メタデータインデックス

全ノートのメタデータを集約したJSONファイルも生成：

```json
{
  "export_date": "2025-11-26T10:30:00+09:00",
  "total_notes": 1527,
  "notebooks": {
    "guid1": "ノートブック1",
    "guid2": "ノートブック2"
  },
  "tags": {
    "guid1": "タグ1",
    "guid2": "タグ2"
  },
  "notes": [
    {
      "guid": "e3bdd511...",
      "title": "平日は毎日",
      "file": "平日は毎日.md",
      "created": "2024-01-15T10:30:00+09:00",
      "updated": "2025-10-20T08:47:00+09:00",
      "notebook": "ノートブック1",
      "tags": ["タグ1", "タグ2"]
    }
  ]
}
```

## 再インポート

このフォーマットは以下の特徴を持ちます：

1. **ENML非依存**: ENMLを知らなくても読み書き可能
2. **EDAM非依存**: GUIDは参照情報として保持するが必須ではない
3. **Git管理可能**: テキストファイルなのでバージョン管理が容易
4. **検索可能**: grepなどの標準ツールで検索可能
5. **編集可能**: 任意のテキストエディタで編集可能

再インポート時は：
- GUIDが一致すれば既存ノート更新
- GUIDがなければ新規ノート作成
- メタデータから適切なEDAM/ENML形式に変換

## 利点

### 人間が読める
```yaml
---
title: 会議メモ
created: 2025-01-15T14:00:00+09:00
tags:
  - 仕事
  - 会議
---

# 会議メモ

## 議題
- プロジェクト進捗
- 次回スケジュール
```

### 検索が容易
```bash
# タイトル検索
grep -r "会議" export/

# タグ検索
grep -r "tags:" export/ | grep "仕事"

# 日付範囲検索
find export/ -name "2025*.md"
```

### バージョン管理
```bash
git add export/
git commit -m "Add meeting notes"
git diff export/会議メモ.md
```

### 他ツールとの連携
- Obsidian: そのまま開ける
- Joplin: インポート可能
- Jekyll/Hugo: 静的サイトジェネレータで利用可能
- VSCode: Markdownプレビュー可能

## コマンド例

```bash
# 全ノートをエクスポート（フラット構造）
enlocal export-all --output export/

# ノートブック別にエクスポート
enlocal export-all --output export/ --structure notebook

# 特定ノートブックのみエクスポート
enlocal export-notebook <GUID> --output export/

# 特定ノートをエクスポート
enlocal export-note <GUID> --output note.md

# メタデータインデックスも生成
enlocal export-all --output export/ --index

# ファイル名形式指定
enlocal export-all --output export/ --filename timestamp-title
```
