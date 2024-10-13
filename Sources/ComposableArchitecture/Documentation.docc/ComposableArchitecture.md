# ``ComposableArchitecture``

Composable Architecture(TCA) は、一貫性があり理解しやすい方法でアプリケーションを構築するためのライブラリです。
コンポジション、テスト、人間工学を念頭に置いて設計されています。
SwiftUI、UIKit、その他のフレームワークで使用でき、Apple のすべてのプラットフォーム(iOS、macOS、tvOS、watchOS)で利用可能です。

## 追加リソース

- [GitHub リポジトリ](https://github.com/pointfreeco/swift-composable-architecture)
- [ディスカッション](https://github.com/pointfreeco/swift-composable-architecture/discussions)
- [Point-Free 動画](https://www.pointfree.co/collections/composable-architecture)

## 概要

このライブラリは、様々な目的や複雑さのアプリケーションを構築するために使用できるいくつかの中核的なツールを提供します。
アプリケーション構築時に日々遭遇する多くの問題を解決するための魅力的な方法を提供します:

- **状態管理**

  シンプルな値型を使用してアプリケーションの状態を管理し、多くの画面間で状態を共有することで、ある画面での変更が即座に別の画面で観察できるようにする方法。

- **コンポジション**

  大きな機能を小さなコンポーネントに分解し、それらを独立したモジュールとして抽出し、再び簡単に組み合わせて機能を形成する方法。

- **副作用**

  アプリケーションの特定の部分が外部世界と通信する際に、最もテスト可能で理解しやすい方法を提供する方法。

- **テスト**

  この設計で構築された機能をテストするだけでなく、多くの部品で構成された機能の統合テストや、副作用がアプリケーションにどのように影響するかを理解するためのエンドツーエンドテストを作成する方法。
  これにより、ビジネスロジックが期待通りに動作していることを強力に保証できます。

- **人間工学**

  上記のすべてを、できるだけ少ない概念と動く部分でシンプルな API で実現する方法。

## トピック

### 基本

- <doc:GettingStarted>
- <doc:DependencyManagement>
- <doc:Testing>
- <doc:Navigation>
- <doc:SharingState>
- <doc:Performance>
- <doc:FAQ>

### チュートリアル

- <doc:MeetComposableArchitecture>
- <doc:BuildingSyncUps>

### 状態管理

- `Reducer`
- `Effect`
- `Store`
- <doc:SharingState>

### テスト

- `TestStore`
- <doc:Testing>

### 統合

- <doc:SwiftConcurrency>
- <doc:SwiftUIIntegration>
- <doc:ObservationBackport>
- <doc:UIKit>

### 移行ガイド

- <doc:MigrationGuides>

## 関連項目

ライブラリの開発に深く踏み込んだ [Point-Free](https://www.pointfree.co) の動画コレクション。

- [Point-Free 動画](https://www.pointfree.co/collections/composable-architecture)
