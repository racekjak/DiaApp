/// Base class for entities. Provides id and toMap().
abstract class BaseEntity {
  Map<String, dynamic> toFirestore();

  BaseEntity();
}
