/// The outcome of an operation that can fail. Callers handle both cases explicitly.
sealed class Result<T> {
  const Result();
}

/// A successful outcome carrying [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

/// A failed outcome carrying the [error] that caused it.
final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}
