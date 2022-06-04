import Foundation

/// A value that represents either a success or a failure. This type differs from Swift's `Result`
/// type in that it uses only one generic for the success case, leaving the failure case as an
/// untyped `Error`.
///
/// This type is needed because Swift's concurrency tools can only express untyped errors, such as
/// `async` functions and `AsyncSequence`, and so their output can realistically only be bridged to
/// `Result<_, Error>`. However, `Result<_, Error>` is never `Equatable` since `Error` is not
/// `Equatable`, and equatability is very important for testing in the Composable Architecture. By
/// defining our own type we get the ability to recover equatability in most situations.
///
/// If someday Swift gets typed `throws`, then we can eliminate this type and rely solely on
/// `Result`.
///
/// You typically use this type as the payload of an action which receives a response from an
/// effect:
///
/// ```swift
/// enum FeatureAction: Equatable {
///   case factButtonTapped
///   case factResponse(TaskResult<String>)
/// }
/// ```
///
/// Then you can model your dependency as using simple `async` and `throws` functionality:
///
/// ```swift
/// struct FeatureEnvironment {
///   var numberFact: @Sendable (Int) async throws -> String
/// }
/// ```
///
/// And finally you can use ``Effect/task(priority:operation:)-4llhw`` to construct an effect in
/// the reducer that invokes the `numberFact` endpoint and wraps its response in a ``TaskResult``
/// by using its catching initializer, ``TaskResult/init(catching:)``:
///
/// ```swift
/// case .factButtonTapped:
///   return .task {
///     await .factResponse(
///       TaskResult { try await environment.numberFact(state.number) }
///     )
///   }
///
/// case .factResponse(.success(fact)):
///   // do something with fact
///
/// case .factResponse(.failure):
///   // handle error
///
/// ...
/// }
/// ```
///
/// ## Equality
///
/// The biggest downside to using an untyped `Error` in a result type is that the result will not
/// be equatable even if the success type is. This negatively affects your ability to test features
/// that use ``TaskResult`` in their actions with the ``TestStore``.
///
///  ``TaskResult`` does extra work to try to maintain equatability when possible. If the underlying
///  type masked by the `Error` is `Equatable`, then it will use that `Equatable` conformance
///  on two failures. If the underlying task is _not_ `Equatable`, then it will cast the failures
///  to `NSError` and check equality there, which works for most simple types.
///
///  Still, sometimes equality on two ``TaskResult`` values can give a false positive, in particular
///  when the custom error type uses features that are not visible to Objective-C, such as enums
///  with associated values:
///
///  ```swift
///  enum CustomError: Error {
///    case server(message: String)
///    case other(Error)
///  }
///
///  let error1 = CustomError.server(message: "Not found")
///  let error2 = CustomError.server(message: "Bad request")
///
///  TaskResult<Int>.failure(error1) == .failure(error2) ✅
///  ```
///
///  These task results are clearly not equal, but when cast to `NSError` they look the same.
///
///  To be safe it is best to always mark your error types as `Equatable`:
///
///  ```swift
///  enum CustomError: Error, Equatable👈 {
///    case server(message: String)
///    case other(Error)
///  }
///
///  let error1 = CustomError.server(message: "Not found")
///  let error2 = CustomError.server(message: "Bad request")
///
///  TaskResult<Int>.failure(error1) == .failure(error2) ❌
///  ```
public enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

#if canImport(_Concurrency) && compiler(>=5.5.2)
  /// Creates a new task result by evaluating an async throwing closure, capturing the returned
  /// value as a success, or any thrown error as a failure.
  ///
  /// This initializer is most often used in an async effect being returned from a reducer. See
  /// the documentation for ``TaskResult`` for a concrete example.
  ///
  /// - Parameter body: An async, throwing closure.
  public init(catching body: @Sendable () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
#endif

  /// Returns the success value as a throwing property.
  public var value: Success {
    get throws {
      switch self {
      case let .success(success):
        return success
      case let .failure(error):
        throw error
      }
    }
  }
}

extension TaskResult: Sendable where Success: Sendable {}

// TODO: do we need this?
//public struct EquatableVoid: Equatable, Codable, Hashable {
//  public init() {}
//}
//
//#if canImport(_Concurrency) && compiler(>=5.5.2)
//  extension TaskResult where Success == EquatableVoid {
//    public init(catching body: @Sendable () async throws -> Void) async {
//      do {
//        try await body()
//        self = .success(.init())
//      } catch {
//        self = .failure(error)
//      }
//    }
//  }
//#endif

public typealias TaskFailure = TaskResult<Never>

extension TaskResult: Equatable where Success: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
      return lhs == rhs
    case let (.failure(lhs), .failure(rhs)):
      return _isEqual(lhs, rhs) ?? ((lhs as NSError) == (rhs as NSError))
    default:
      return false
    }
  }
}

extension TaskResult: Hashable where Success: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case let .success(success):
      hasher.combine(success)
    case let .failure(failure):
      if !_hash(failure, into: &hasher) {
        hasher.combine(failure as NSError)
      }
    }
  }
}

private enum _Witness<A> {}

private protocol _AnyEquatable {
  static func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool
}
private protocol _AnyHashable: _AnyEquatable {
  static func _hash(_ value: Any, into hasher: inout Hasher) -> Bool
}

extension _Witness: _AnyEquatable where A: Equatable {
  static func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard
      let lhs = lhs as? A,
      let rhs = rhs as? A
    else { return false }
    return lhs == rhs
  }
}

extension _Witness: _AnyHashable where A: Hashable {
  static func _hash(_ value: Any, into hasher: inout Hasher) -> Bool {
    guard let value = value as? A
    else { return false }
    hasher.combine(value)
    return true
  }
}

private func _isEqual(_ a: Any, _ b: Any) -> Bool? {
  func `do`<A>(_: A.Type) -> Bool? {
    (_Witness<A>.self as? _AnyEquatable.Type)?._isEqual(a, b)
  }
  return _openExistential(type(of: a), do: `do`)
}

private func _hash(_ value: Any, into hasher: inout Hasher) -> Bool {
  func `do`<A>(_: A.Type) -> Bool {
    guard let hashable = (_Witness<A>.self as? _AnyHashable.Type)
    else { return false }
    return hashable._hash(value, into: &hasher)
  }
  return _openExistential(type(of: value), do: `do`)
}
