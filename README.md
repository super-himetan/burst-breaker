# Burst Breaker

3〜5分で遊べる、ブロック崩し型ローグライトの試作です（Godot 4.6）。

狙いたい場所を指して玉を発射します。Mac はカーソルで狙ってクリック、スマホは指で触れて狙い、離すと発射します。

## やり込み要素

- 左右対称の隊列で降りてくる、形の違うブロックと、壁やバンパーなどの仕掛け
- ステージの合間に選ぶ分岐ルート（危険な道、呪いの祭壇、行商人、祠、宝の部屋）
- 強化と呪い、進化、究極進化、遺物、相棒、操縦者、契約、毎ランの任務
- 玉8種と熟練度、4つの章と属性相性、玉ごとの必殺技「バースト」
- ボス13体（覚醒、共闘、裏ボスと真エンド）、ボスラッシュ、門番の物語と手記
- 節目ボーナスつきのショップ、上限のない難易度、累計コインで増える星とスキルツリー
- 天候と重力、スイッチや鍵の仕掛け、ボーナスステージ、合成炉、ボスの部位破壊
- スタイルランク、実績、図鑑、見た目の収集、記念カード

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

実際の入力イベントで通しプレイし、スクリーンショットと `report.json` を保存します。音量設定に関わらず無音で動きます。

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
- `perk_art.gd`: 強化カードのアイコン
- `data/star_tree.gd`: 星のスキルツリー
- `data/formations.gd`: ブロックの隊列
- `data/layouts.gd`: ステージの仕掛け
- `data/run_content.gd`: 遺物、ルート、祠、契約、操縦者、任務
- `data/worlds.gd`: 章と属性
- `data/cosmetics.gd`: 見た目
- `menus.gd`: ゲーム以外の各画面
- `verify.gd`: 実際の入力で全画面を通す確認
- `data/`: 強化、玉、ショップ、難易度、実績の定義
- `tests/run_tests.gd`: ルールとデータのテスト
- `tests/balance.gd`: ボットによる長期プレイと強さの比較
