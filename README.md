# PocketBase Repository Implementation

A PocketBase implementation of the `kiss_repository` interface for clean, type-safe data operations with real-time capabilities.

## Overview

This package implements the `kiss_repository` interface for PocketBase, providing a clean and simple repository pattern for PocketBase applications. PocketBase offers excellent text search, real-time subscriptions, and flexible authentication - making it ideal for applications that need full-featured database operations without the complexity of larger systems.

## ✨ Features & Limitations

### ✅ Standard Repository Features
- ✅ Complete CRUD operations (Create, Read, Update, Delete)
- ✅ Batch operations for multiple items
- ✅ Type-safe data conversions between Dart and backend
- ✅ Custom query building with `QueryBuilder`
- ✅ Built-in error handling with typed exceptions

### 🗄️ PocketBase-Specific Features
- ✅ **Real-time streaming** with PocketBase WebSocket subscriptions
- ✅ **Multi-instance streaming** - Works across multiple server instances/deployments
- ✅ Auto-generated IDs (custom repository function)
- ✅ Case-insensitive text search with contains matching
- ✅ Pure Dart package (works in any Dart environment)
- ✅ Advanced authentication with auth collections
- ✅ Self-hosted data control

### 📡 Streaming Architecture
- ✅ **Server-Side Streaming**: WebSocket-based real-time subscriptions
- ✅ **Multi-Instance Support**: Changes from any client broadcast to all connected subscribers
- ✅ **Self-Hosted Control**: Full control over real-time infrastructure and data flow
- ✅ **Perfect for**: Self-hosted applications with real-time requirements
- ✅ **Horizontal Scaling**: WebSocket connections work across multiple server instances
- ✅ **Full Control**: Complete ownership of data and streaming infrastructure

### ⚠️ Limitations
- **Collection schemas required**: Must define collections in Admin Dashboard first
- **Self-hosted only**: Requires running your own PocketBase instance
- **Learning curve**: PocketBase-specific concepts (auth collections, rules)

## 🚀 Quick Start

### Prerequisites
- Dart SDK ^3.8.0
- PocketBase binary for local development
- Basic understanding of PocketBase collections and auth

#### Installing PocketBase

```bash
brew install pocketbase
```

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  kiss_pocketbase_repository: ^0.1.0
```

### Basic Usage

```dart
import 'package:kiss_pocketbase_repository/kiss_pocketbase_repository.dart';

// 1. Define your model
class User {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  User({required this.id, required this.name, required this.email, required this.createdAt});
  
  User copyWith({String? id, String? name, String? email, DateTime? createdAt}) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// 2. Create repository
final userRepository = RepositoryPocketBase<User>(
  collectionName: 'users',
  toPocketBase: (user) => {
    'name': user.name,
    'email': user.email,
    'createdAt': user.createdAt.toIso8601String(),
  },
  fromPocketBase: (record) => User(
    id: record.id,
    name: record.data['name'],
    email: record.data['email'],
    createdAt: DateTime.parse(record.data['createdAt']),
  ),
);

// 3. Use it
final newUser = await userRepository.add(
  IdentifedObject('user123', User(
    id: 'user123',
    name: 'John Doe',
    email: 'john@example.com',
    createdAt: DateTime.now(),
  )),
);
```

## 🔧 Development Setup

### PocketBase Local Setup

```bash
# Start PocketBase with test collections and users
./scripts/start_emulator.sh
```

PocketBase runs on:
- **API**: `http://localhost:8090`
- **Admin Dashboard**: `http://localhost:8090/_/`

### Running Tests

```bash
# Integration tests (handles test setup automatically)
./scripts/run_tests.sh
```

### Manual Development

```bash
# Start PocketBase with test setup (in one terminal)
./scripts/start_emulator.sh

# Run example app (in another terminal)
flutter run
```

### Collection Setup

**Option 1: Admin Dashboard**
1. **Open Admin Dashboard** at `http://localhost:8090/_/`
2. **Create collections** with required fields
3. **Set up API rules** for permissions
4. **Configure auth collections** if using authentication

**Option 2: Programmatically (API)**
```bash
# Automated collection creation (included in start_emulator.sh)
./scripts/start_emulator.sh
```
Collections can be created via API calls using JSON definitions.

## 📖 Usage

### Auto-Generated PocketBase IDs

```dart
// PocketBase automatically generates IDs
final item = repository.createWithAutoId(
  User(id: '', name: 'John Doe', email: 'john@example.com', createdAt: DateTime.now()),
  (user, id) => user.copyWith(id: id),
);

final savedUser = await repository.add(item);
print(savedUser.id); // PocketBase-generated ID (15 characters)
```

### Batch Operations

```dart
// Add multiple users
await userRepository.addAll([
  IdentifedObject('id1', user1),
  IdentifedObject('id2', user2),
]);

// Update multiple users
await userRepository.updateAll([
  IdentifedObject('id1', updatedUser1),
  IdentifedObject('id2', updatedUser2),
]);

// Delete multiple users
await userRepository.deleteAll(['id1', 'id2']);
```

### Real-time Streaming

```dart
// Stream single record
userRepository.stream('user_id').listen((user) {
  print('User updated: ${user.name}');
});

// Stream query results
userRepository.streamQuery().listen((users) {
  print('Total users: ${users.length}');
});
```

### Advanced Text Search

```dart
class UserQueryBuilder implements QueryBuilder<PocketBaseQuery> {
  @override
  PocketBaseQuery build(Query query) {
    if (query is SearchUsersQuery) {
      // Case-insensitive search across multiple fields
      return PocketBaseQuery(
        filter: 'name ~ "${query.searchTerm}" || email ~ "${query.searchTerm}"',
        sort: 'name',
      );
    }
    
    if (query is ActiveUsersQuery) {
      return PocketBaseQuery(
        filter: 'status = "active"',
        sort: '-lastActive',
      );
    }
    
    return PocketBaseQuery(sort: '-created');
  }
}

// Use advanced search
final results = await userRepository.query(
  query: SearchUsersQuery('john'), // Finds "John", "JOHN", "johnny"
);
```

### Authentication & Permissions

```dart
// Auth collections for user management
class AuthUserRepository extends RepositoryPocketBase<AuthUser> {
  AuthUserRepository() : super(
    collectionName: 'users', // Auth collection
    // ... configuration
  );
  
  // Login users
  Future<AuthUser> login(String email, String password) async {
    final authData = await pb.collection('users').authWithPassword(email, password);
    return fromPocketBase(authData.record);
  }
}
```

## 🎯 PocketBase Essentials

### Collections & Authentication

**Auth Collections** replace traditional user/role systems:
- Mark collections as `auth` type in Admin Dashboard
- Built-in fields: `email`, `password`, `verified`, `tokenKey`
- Add custom fields: `name`, `avatar`, `department`, `role`
- Collections can represent broad roles (`admins`, `staff`, `customers`)

**Permission Rules** control access:
```javascript
// Collection-based permissions
createRule: "@request.auth.collectionName = 'staff'"

// Field-based permissions  
deleteRule: "@request.auth.role = 'admin'"

// Combined approach
updateRule: "@request.auth.collectionName = 'staff' && @request.auth.role = 'manager'"
```

### Workflow
1. **Create collections** in Admin Dashboard
2. **Define API rules** for permissions
3. **Use repository** for CRUD operations

## 🔄 Comparison with Other Implementations

For a detailed comparison of all repository implementations, see the [main documentation](https://github.com/WAMF/kiss_repository#comparison-table).

## 📁 Example Application

See the [example](https://github.com/WAMF/kiss_repository/tree/main/example) directory for a complete Flutter app demonstrating:

- Real-time user management with PocketBase
- Advanced text search and filtering
- Auth collection patterns
- CRUD operations with modern UI
- Integration tests with local PocketBase

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License
