import 'dart:async';
import 'dart:math';

import 'package:kiss_repository/kiss_repository.dart';
import 'package:pocketbase/pocketbase.dart';

/// Special IdentifiedObject subclass that generates PocketBase IDs on-demand
class PocketBaseIdentifiedObject<T> extends IdentifiedObject<T> {
  PocketBaseIdentifiedObject(T object, this._updateObjectWithId) : super('', object);

  final T Function(T object, String id) _updateObjectWithId;
  String? _cachedId;
  T? _cachedUpdatedObject;

  @override
  String get id {
    _cachedId ??= _generatePocketBaseId();
    return _cachedId!;
  }

  @override
  T get object {
    if (_cachedUpdatedObject == null) {
      final generatedId = id; // This will generate and cache the ID if needed
      _cachedUpdatedObject = _updateObjectWithId(super.object, generatedId);
    }
    return _cachedUpdatedObject!;
  }

  /// Generates a real PocketBase ID directly within the object
  String _generatePocketBaseId() {
    return PocketBaseIdentifiedObject.generateId();
  }

  static String generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(15, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static bool isValidId(String id) {
    if (id.length != 15) return false;
    final validChars = RegExp(r'^[a-z0-9]+$');
    return validChars.hasMatch(id);
  }

  static void validateId(String id) {
    if (!isValidId(id)) {
      throw RepositoryException(
        message:
            'Invalid PocketBase ID format. ID must be exactly 15 characters '
            'and contain only lowercase alphanumeric characters (a-z0-9). '
            'Got: "$id" (length: ${id.length})',
      );
    }
  }

  /// Convenience factory method for creating objects with auto-generated IDs
  factory PocketBaseIdentifiedObject.create(T object, T Function(T object, String id) updateObjectWithId) =>
      PocketBaseIdentifiedObject(object, updateObjectWithId);
}

class RepositoryPocketBase<T> extends Repository<T> {
  RepositoryPocketBase({
    required this.client,
    required this.collection,
    required this.fromPocketBase,
    required this.toPocketBase,
    this.queryBuilder,
  });

  final PocketBase client;
  final String collection;
  final T Function(RecordModel record) fromPocketBase;
  final Map<String, dynamic> Function(T object) toPocketBase;
  final QueryBuilder<String>? queryBuilder;

  @override
  String get path => collection;

  @override
  Future<T> get(String id) async {
    try {
      final record = await client.collection(collection).getOne(id);
      return fromPocketBase(record);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        throw RepositoryException.notFound(id);
      }
      throw RepositoryException(message: 'Failed to get record: ${e.response}');
    } catch (e) {
      throw RepositoryException(message: 'Failed to get record: $e');
    }
  }

  @override
  Future<T> add(IdentifiedObject<T> item) async {
    PocketBaseIdentifiedObject.validateId(item.id);

    try {
      final data = toPocketBase(item.object);

      final record = await client.collection(collection).create(body: data);
      return fromPocketBase(record);
    } on ClientException catch (e) {
      if (e.statusCode == 400 && e.response['data'] != null) {
        final errors = e.response['data'] as Map;
        if (errors.containsKey('id')) {
          throw RepositoryException.alreadyExists(item.id);
        }
      }
      throw RepositoryException(message: 'Failed to add record: ${e.response}');
    } catch (e) {
      throw RepositoryException(message: 'Failed to add record: $e');
    }
  }

  @override
  Future<T> update(String id, T Function(T current) updater) async {
    try {
      final currentRecord = await client.collection(collection).getOne(id);
      final current = fromPocketBase(currentRecord);

      final updated = updater(current);
      final data = toPocketBase(updated);

      final updatedRecord = await client.collection(collection).update(id, body: data);
      return fromPocketBase(updatedRecord);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        throw RepositoryException.notFound(id);
      }
      throw RepositoryException(message: 'Failed to update record: ${e.response}');
    } catch (e) {
      throw RepositoryException(message: 'Failed to update record: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await client.collection(collection).delete(id);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        // Silently succeed for non-existent records
        return;
      }
      throw RepositoryException(message: 'Failed to delete record: ${e.response}');
    } catch (e) {
      throw RepositoryException(message: 'Failed to delete record: $e');
    }
  }

  @override
  Future<List<T>> query({Query query = const AllQuery()}) async {
    try {
      String? filter;
      String? sort;

      if (query is AllQuery) {
        sort = '-created'; // Sort by creation date descending (newest first)
      } else if (queryBuilder != null) {
        filter = queryBuilder!.build(query);
      } else {
        throw RepositoryException(
          message:
              'Query builder required for custom queries. '
              'Please provide a QueryBuilder<String> in the repository constructor.',
        );
      }

      final records = await client.collection(collection).getFullList(filter: filter, sort: sort ?? '-created');

      return records.map((record) => fromPocketBase(record)).toList();
    } on ClientException catch (e) {
      throw RepositoryException(message: 'Failed to query records: ${e.response}');
    } catch (e) {
      throw RepositoryException(message: 'Failed to query records: $e');
    }
  }

  /// Creates a real-time stream of changes for a specific document.
  ///
  /// **Initial Emission**: Immediately emits existing data when subscribed (BehaviorSubject-like).
  /// **Deletion Behavior**: PocketBase sends delete events. Stream closes on deletion.
  @override
  Stream<T> stream(String id) {
    PocketBaseIdentifiedObject.validateId(id);

    late StreamController<T> controller;
    bool isSubscribed = false;

    controller = StreamController<T>(
      onListen: () async {
        try {
          // First, get and emit initial data BEFORE setting up real-time subscription
          try {
            final initialData = await get(id);
            controller.add(initialData);
          } catch (e) {
            controller.addError(e);
          }

          await client.collection(collection).subscribe(id, (event) {
            try {
              if (event.action == 'delete') {
                // If this is a delete event, close the stream
                controller.close();
                return;
              }

              final record = event.record;
              if (record != null) {
                final domainObject = fromPocketBase(record);
                controller.add(domainObject);
              }
            } catch (e) {
              controller.addError(RepositoryException(message: 'Failed to process stream event: $e'));
            }
          });
          isSubscribed = true;
        } catch (e) {
          controller.addError(RepositoryException(message: 'Failed to establish stream subscription: $e'));
        }
      },
      onCancel: () async {
        if (isSubscribed) {
          try {
            await client.collection(collection).unsubscribe(id);
          } catch (e) {
            // Log error but don't throw - cleanup should be best effort
            print('Warning: Failed to unsubscribe from PocketBase stream: $e');
          }
        }
      },
    );

    return controller.stream;
  }

  @override
  Stream<List<T>> streamQuery({Query query = const AllQuery()}) {
    late StreamController<List<T>> controller;
    bool isSubscribed = false;

    controller = StreamController<List<T>>(
      onListen: () async {
        try {
          // First, get and emit initial data BEFORE setting up real-time subscription
          try {
            final initialData = await this.query(query: query);
            controller.add(initialData);
          } catch (e) {
            controller.addError(RepositoryException(message: 'Failed to get initial stream query data: $e'));
          }

          await client.collection(collection).subscribe('*', (event) async {
            try {
              final results = await this.query(query: query);
              controller.add(results);
            } catch (e) {
              controller.addError(RepositoryException(message: 'Failed to process stream query event: $e'));
            }
          });
          isSubscribed = true;
        } catch (e) {
          controller.addError(RepositoryException(message: 'Failed to establish stream query subscription: $e'));
        }
      },
      onCancel: () async {
        if (isSubscribed) {
          try {
            await client.collection(collection).unsubscribe('*');
          } catch (e) {
            print('Warning: Failed to unsubscribe from PocketBase stream query: $e');
          }
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<Iterable<T>> addAll(Iterable<IdentifiedObject<T>> items) async {
    final results = <T>[];
    final exceptions = <String, Exception>{};

    for (final item in items) {
      try {
        final result = await add(item);
        results.add(result);
      } catch (e) {
        exceptions[item.id] = e is Exception ? e : Exception(e);
      }
    }

    if (exceptions.isNotEmpty) {
      throw RepositoryException(
        message: 'Batch add failed for ${exceptions.length} items: ${exceptions.keys.join(', ')}',
      );
    }

    return results;
  }

  @override
  Future<Iterable<T>> updateAll(Iterable<IdentifiedObject<T>> items) async {
    final results = <T>[];
    final exceptions = <String, Exception>{};

    for (final item in items) {
      try {
        final result = await update(item.id, (_) => item.object);
        results.add(result);
      } catch (e) {
        exceptions[item.id] = e is Exception ? e : Exception(e);
      }
    }

    if (exceptions.isNotEmpty) {
      throw RepositoryException(
        message: 'Batch update failed for ${exceptions.length} items: ${exceptions.keys.join(', ')}',
      );
    }

    return results;
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    final exceptions = <String, Exception>{};

    for (final id in ids) {
      try {
        await delete(id);
      } catch (e) {
        exceptions[id] = e is Exception ? e : Exception(e);
      }
    }

    if (exceptions.isNotEmpty) {
      throw RepositoryException(
        message: 'Batch delete failed for ${exceptions.length} items: ${exceptions.keys.join(', ')}',
      );
    }
  }

  @override
  Future<void> dispose() async {
    // Nothing to dispose for PocketBase
  }

  @override
  IdentifiedObject<T> autoIdentify(T object, {T Function(T object, String id)? updateObjectWithId}) {
    return PocketBaseIdentifiedObject(object, updateObjectWithId ?? (object, id) => object);
  }

  @override
  Future<T> addAutoIdentified(T object, {T Function(T object, String id)? updateObjectWithId}) async {
    final autoIdentifiedObject = autoIdentify(object, updateObjectWithId: updateObjectWithId);
    return add(autoIdentifiedObject);
  }
}
