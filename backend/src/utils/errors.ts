export class AppError extends Error {
  constructor(
    message: string,
    public statusCode = 400,
    public errors: unknown[] = []
  ) {
    super(message);
  }
}
