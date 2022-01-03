abstract class ResponseBuilder {
  T buildContent<T>(Map databaseRow);
  // List<T> buildResponse<T>(List<Map<String, Object?>> databaseResult);
}
