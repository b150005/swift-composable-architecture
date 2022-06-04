import Combine
import SwiftUI

#if canImport(_Concurrency) && compiler(>=5.5.2)
  extension Effect where Failure == Never {
    /// Wraps an asynchronous unit of work in an effect.
    ///
    /// This function is useful for executing work in an asynchronous context and capture the
    /// result in an ``Effect`` so that the reducer, a non-asynchronous context, can process it.
    ///
    /// For example, if your environment contains a dependency that exposes an `async` function,
    /// you can use ``Effect/task(priority:operation:)-4llhw`` to provide an asynchronous context
    /// for invoking that endpoint:
    ///
    /// ```swift
    /// struct FeatureEnvironment {
    ///   var numberFact: @Sendable (Int) async throws -> String
    /// }
    ///
    /// enum FeatureAction {
    ///   case factButtonTapped
    ///   case faceResponse(TaskResult<String>)
    /// }
    ///
    /// let featureReducer = Reducer<State, Action, Environment> { state, action, environment in
    ///   switch action {
    ///     case .factButtonTapped:
    ///       return .task {
    ///         await .factResponse(.init { try await environment.numberFact(state.number) })
    ///       }
    ///
    ///     case .factResponse(.success(fact)):
    ///       // do something with fact
    ///
    ///     case .factResponse(.failure):
    ///       // handle error
    ///
    ///     ...
    ///   }
    /// }
    /// ```
    ///
    /// Note that the operation provided to ``Effect/task(priority:operation:)-4llhw`` cannot throw
    /// and so you must either handle errors directly in the closure or use the catching initializer
    /// of ``TaskResult/init(catching:)`` to package the response into a ``TaskResult`` and send
    /// it back into the system via an action.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - operation: The operation to execute.
    /// - Returns: An effect wrapping the given asynchronous work.
    public static func task(
      priority: TaskPriority? = nil,
      operation: @escaping @Sendable () async -> Output
    ) -> Self where Failure == Never {
      Deferred<Publishers.HandleEvents<PassthroughSubject<Output, Failure>>> {
        let subject = PassthroughSubject<Output, Failure>()
        let task = Task(priority: priority) { @MainActor in
          do {
            try Task.checkCancellation()
            let output = await operation()
            try Task.checkCancellation()
            subject.send(output)
            subject.send(completion: .finished)
          } catch is CancellationError {
            subject.send(completion: .finished)
          } catch {
            subject.send(completion: .finished)
          }
        }
        return subject.handleEvents(receiveCancel: task.cancel)
      }
      .eraseToEffect()
    }

    public static func run(
      priority: TaskPriority? = nil,
      _ operation: @escaping @Sendable (_ send: Send<Output>) async -> Void
    ) -> Self {
      .run { subscriber in
        let task = Task(priority: priority) { @MainActor in
          await operation(Send(send: { subscriber.send($0) }))
          subscriber.send(completion: .finished)
        }
        return AnyCancellable {
          task.cancel()
        }
      }
    }

    /// Creates an effect that executes some work in the real world that doesn't need to feed data
    /// back into the store. If an error is thrown, the effect will complete and the error will be
    /// ignored.
    ///
    /// - Parameters:
    ///   - priority: Priority of the underlying task. If `nil`, the priority will come from
    ///     `Task.currentPriority`.
    ///   - work: A closure encapsulating some work to execute in the real world.
    /// - Returns: An effect.
    public static func fireAndForget(
      priority: TaskPriority? = nil,
      _ work: @escaping @Sendable () async throws -> Void
    ) -> Self {
      Effect<Void, Never>.task(priority: priority) { try? await work() }
        .fireAndForget()
    }
  }

  @MainActor
  public struct Send<Action> {
    let send: @Sendable (Action) -> Void

    public func callAsFunction(_ action: Action) {
      self.send(action)
    }

    public func callAsFunction(_ action: Action, animation: Animation? = nil) {
      withAnimation(animation) {
        self.send(action)
      }
    }
  }

  extension Send: Sendable where Action: Sendable {}

  extension Send where Action: BindableAction {
    public func callAsFunction<Value>(
      set keyPath: WritableKeyPath<Action.State, BindableState<Value>>,
      to value: Value
    ) where Value: Equatable {
      self.send(.set(keyPath, value))
    }

    public func callAsFunction<Value>(
      set keyPath: WritableKeyPath<Action.State, BindableState<Value>>,
      to value: Value,
      animation: Animation? = nil
    ) where Value: Equatable {
      self(.set(keyPath, value), animation: animation)
    }
  }
#endif
