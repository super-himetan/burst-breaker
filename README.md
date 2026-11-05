# Burst Breaker

3〜5分で遊べる、ブロック崩し型ローグライトの試作です（Godot 4.6）。

狙いたい場所を指して玉を発射します。Mac はカーソルで狙ってクリック、スマホは指で触れて狙い、離すと発射します。

## やり込み要素

- 強化60種（進化12種を含む）と、実績による段階的な解放
- 9系統のビルド：持っている系統の強化が出やすくなり、カードに進化への道筋が出る
- 玉8種、特殊ブロック7種、個性の違うボス6体（登場演出とセリフつき）
- コインで買える永続強化のショップ
- 上限のない難易度と、転生による星の倍率
- 実績129個と図鑑（ボスのページつき）
- 玉ごとに違う必殺技「バースト」

## Mac での操作

マウスで狙ってクリックで発射します。ホイールとトラックパッドで一覧をスクロールできます。

| キー | 動作 |
|---|---|
| Esc | ポーズ、ひとつ前の画面へ戻る |
| Space / Enter / R | もう一度、再開、バースト |
| 1〜4 | 強化カードを選ぶ |

## 実行

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Mac 用のビルド

`build/macos/BurstBreaker.app` を作ります。この Mac ではそのまま起動できます。

```bash
mkdir -p build/macos && touch build/.gdignore && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release macOS build/macos/BurstBreaker.app
```

## iOS への書き出し

Xcode と Godot の書き出しテンプレート、`export_presets.cfg` の `application/app_store_team_id` が必要です。シミュレーターには書き出せないので、実機で確認します。

```bash
mkdir -p build/ios && touch build/.gdignore && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug iOS build/ios/BurstBreaker.xcodeproj
```

書き出した `build/ios/BurstBreaker.xcodeproj` を Xcode で開いて、ビルドします。

## 確認

ルールとデータのテストです。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd
```

実際の入力イベントで通しプレイし、スクリーンショットと `report.json` を保存します。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --always-on-top -- --verify="$PWD/verify-output"
```

ボットで長期プレイを模擬します。`perks` `balls` `bosses` `builds` で強化、玉、ボス、ビルド系統の強さも比較できます。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/balance.gd -- campaign 100 1
```

## 構成

- `sim/game_sim.gd`: ゲームのルール（描画に依存しない）
- `main.gd`: 画面遷移、入力、ゲーム画面、エフェクト、効果音
- `i18n.gd`: 表示テキスト（日本語が基本で、英語も選べる）
- `save_data.gd`: 設定と記録の保存
- `music.gd`: コードで生成する BGM
- `menus.gd`: ゲーム以外の各画面
- `verify.gd`: 実際の入力で全画面を通す確認
- `data/`: 強化、玉、ショップ、難易度、実績の定義
- `tests/run_tests.gd`: ルールとデータのテスト
- `tests/balance.gd`: ボットによる長期プレイと強さの比較
