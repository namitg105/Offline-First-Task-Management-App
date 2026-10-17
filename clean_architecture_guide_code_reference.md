# Clean Architecture Guide & Code Reference

Clean Architecture is not just a folder structure—it is a strict discipline. It is the art of decoupling your business logic from external frameworks, databases, and UI components so your application remains testable, maintainable, and completely independent of third-party drivers.

---

## 1. The Core Architectural Philosophy

Clean Architecture divides a software system into concentric layers, ensuring that business logic remains independent of UI, databases, and external frameworks. Following the **Dependency Rule**: Dependencies must only point inward. Outer layers know about inner layers, but inner layers know absolutely nothing about outer layers.

```text
      +-------------------------------------------+
      |  PRESENTATION LAYER (UI, Blocs, Pages)    |
      +---------------------+---------------------+
                            | (depends on)
                            v
      +-------------------------------------------+
      |     DOMAIN LAYER (Entities, Use Cases)    | <--- The Core (Zero Dependencies)
      +---------------------+---------------------+
                            ^
                            | (implements interfaces of)
      +---------------------+---------------------+
                            |
      +-------------------------------------------+
      |  DATA LAYER (Models, Repositories, Sources)|
      +-------------------------------------------+
```

---

## 2. Feature-First Folder Structure

The codebase is modularized by feature rather than by layer type at the root level. Every feature folder contains three subfolders representing the core layers.

```text
lib/
├── core/                        # Shared across all features
│   ├── common/                  # Global entities, widgets, cubits
│   ├── secrets/                 # API keys, Supabase credentials
│   ├── theme/                   # App colors, text themes
│   ├── usecase/                 # Base UseCase interface
│   ├── utils/                   # Pick image, show snackbar
│   └── error/                   # Failures & ServerException
├── init_dependencies.dart       # Dependency Injection (GetIt)
├── main.dart                    # Root entry point & App initialization
└── features/
    ├── auth/                    # Authentication Feature
    │   ├── domain/              # Entities, Use Cases, Repository Interfaces
    │   ├── data/                # Models, Datasources, Repository Implementations
    │   └── presentation/        # UI Widgets, Pages, Blocs/Events/States
    └── blog/                    # Other Features (e.g., Blog Feature)
        ├── domain/
        ├── data/
        └── presentation/
```

---

## 3. Deep-Dive Layer Breakdown & Class Inventories

### I. Domain Layer (The Core Business Domain)
This is the heart of the application. It contains pure Dart code without any Flutter UI, Supabase, Hive, or JSON serialization logic.

* **Entities:**
  * **User:** Holds core user fields (`id`, `email`, `name`).
  * **Blog:** Holds blog fields (`id`, `posterId`, `title`, `content`, `imageUrl`, `topics`, `updatedAt`, `posterName`).
* **Repository Interfaces (Contracts):**
  * **AuthRepository:** Abstract class defining methods like `signUpWithEmailPassword()`, `loginWithEmailPassword()`, and `currentUser()`. Returns functional error handles (`Either<Failure, User>`).
  * **BlogRepository:** Abstract class defining `uploadBlog()`, `getAllBlogs()`, etc.
* **Use Cases (Single Responsibility Principle):**
  * **UserSignUp:** Executes user registration logic.
  * **UserLogin:** Executes user login logic.
  * **CurrentUser:** Fetches the currently authenticated session user.
  * **UploadBlog:** Validates input and triggers blog upload.
  * **GetAllBlogs:** Retrieves all blogs (from local cache or remote).
* **Core Interfaces / Base Classes:**
  * **`UseCase<SuccessType, Params>`:** Generic abstract class forcing all use cases to implement a `call(Params params)` method.

### II. Data Layer (Data Sources & Models)
This layer handles network requests, local database persistence, and converts raw remote JSON into strong domain entities.

* **Models (Extends Domain Entities):**
  * **UserModel:** Inherits from `User`. Implements `fromJson()`, `toJson()`, and `copyWith()`.
  * **BlogModel:** Inherits from `Blog`. Handles serialization between Supabase/Hive tables and the application domain.
* **Data Sources (Raw API/DB Handlers):**
  * **Remote Data Sources:**
    * `AuthRemoteDataSource` / `AuthRemoteDataSourceImpl`: Direct interactions with the `SupabaseClient` for auth endpoints.
    * `BlogRemoteDataSource` / `BlogRemoteDataSourceImpl`: Uploads files/images to Supabase Storage and fetches records from the Supabase database.
  * **Local Data Sources (Caching Layer for Offline Access):**
    * `BlogLocalDataSource` / `BlogLocalDataSourceImpl`: Stores and fetches `BlogModel` objects from local storage using Hive.
* **Repository Implementations (Bridge between Domain and Data):**
  * **AuthRepositoryImpl:** Implements `AuthRepository`. Catches exceptions (`ServerException`) and converts them into `Failure` objects using `fpdart` (`Either<Failure, User>`).
  * **BlogRepositoryImpl:** Implements `BlogRepository`. Manages internet connectivity checks—fetches from `BlogRemoteDataSource` when online and writes to Hive; fetches from `BlogLocalDataSource` when offline.

### III. Presentation Layer (State Management & UI)
This layer handles state rendering, UI layout, user interactions, and event handling via BLoC (Business Logic Component).

* **State Management (BLoC / Cubit):**
  * **AuthBloc:**
    * *Events:* `AuthSignUp`, `AuthLogin`, `AuthIsUserLoggedIn`.
    * *States:* `AuthInitial`, `AuthLoading`, `AuthSuccess`, `AuthFailure`.
  * **BlogBloc:**
    * *Events:* `BlogUpload`, `BlogFetchAllBlogs`.
    * *States:* `BlogInitial`, `BlogLoading`, `BlogFailure`, `BlogUploadSuccess`, `BlogsDisplaySuccess`.
  * **AppUserCubit:** A persistent global state cubit holding the active `User` session across the application lifecycle.
* **UI Views & Pages:**
  * `LoginPage`, `SignUpPage`: Collect user inputs and dispatch `AuthLogin` / `AuthSignUp` events.
  * `BlogPage`: Displays the list of blogs with `BlocBuilder`. Handles pull-to-refresh and navigates to creation or detail screens.
  * `AddNewBlogPage`: Handles image selection, text inputs, topic chip selections, and dispatches `BlogUpload`.
  * `BlogViewerPage`: Displays detailed single-blog views.
* **Reusable Widgets & Utilities:**
  * `AuthField`, `AuthGradientButton`, `BlogCard`, `BlogEditor`, `Loader`.

---

## 4. Cross-Cutting Core Utilities (`/core`)

These files serve as the infrastructure that ties the Clean Architecture layers together without breaking architectural boundaries:

* **Error Handling (`core/error/`):**
  * **Failure:** Abstract class for app-level failures (`ServerFailure`).
  * **ServerException:** Exception thrown by data sources when remote calls fail.
* **Base UseCase Contract (`core/usecase/`):**
  * **`usecase.dart`:** Enforces standardized calls across every use case in the application.
* **Dependency Injection (`init_dependencies.dart`):**
  * Uses `GetIt` (`sl` - Service Locator) to register singletons and factories.
  * Configures instances in order: External Services (Supabase/Hive) $\rightarrow$ Data Sources $\rightarrow$ Repositories $\rightarrow$ Use Cases $\rightarrow$ Blocs/Cubits.
* **Network Information (`core/network/`):**
  * **ConnectionChecker:** Uses `internet_connection_checker_plus` to determine online/offline status for offline-first caching strategies.

---

## 5. Core Code Implementations

### Core Layer Files

#### `lib/core/error/failures.dart`
```dart
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final List<dynamic> properties;
  const Failure([this.properties = const <dynamic>[]]);

  @override
  List<Object?> get props => [properties];
}

class ServerFailure extends Failure {}
class CacheFailure extends Failure {}
```

#### `lib/core/usecases/usecase.dart`
```dart
import 'package:dartz/dartz.dart';
import '../error/failures.dart';

abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
```

---

### Feature Layer Example (`user`)

#### Domain Layer

**`lib/features/user/domain/entities/user_entity.dart`**
```dart
import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
  });

  @override
  List<Object?> get props => [id, name, email];
}
```

**`lib/features/user/domain/repositories/user_repository.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<Either<Failure, UserEntity>> getUserProfile(String userId);
}
```

**`lib/features/user/domain/usecases/get_user_profile.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/user_repository.dart';

class GetUserProfile implements UseCase<UserEntity, String> {
  final UserRepository repository;

  GetUserProfile(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(String userId) async {
    return await repository.getUserProfile(userId);
  }
}
```

#### Data Layer

**`lib/features/user/data/models/user_model.dart`**
```dart
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required String id,
    required String name,
    required String email,
  }) : super(id: id, name: name, email: email);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}
```

**`lib/features/user/data/datasources/user_remote_data_source.dart`**
```dart
import '../models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<UserModel> getUserProfile(String userId);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  // Inject HTTP Client or Supabase Client here

  @override
  Future<UserModel> getUserProfile(String userId) async {
    // Perform API call and return UserModel
    throw UnimplementedError();
  }
}
```

**`lib/features/user/data/repositories/user_repository_impl.dart`**
```dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, UserEntity>> getUserProfile(String userId) async {
    try {
      final userModel = await remoteDataSource.getUserProfile(userId);
      return Right(userModel);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
```

#### Presentation Layer

**`lib/features/user/presentation/bloc/user_event.dart`**
```dart
import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object> get props => [];
}

class FetchUserProfile extends UserEvent {
  final String userId;

  const FetchUserProfile(this.userId);

  @override
  List<Object> get props => [userId];
}
```

**`lib/features/user/presentation/bloc/user_state.dart`**
```dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class UserState extends Equatable {
  const UserState();
  
  @override
  List<Object> get props => [];
}

class UserInitial extends UserState {}
class UserLoading extends UserState {}
class UserLoaded extends UserState {
  final UserEntity user;
  const UserLoaded(this.user);

  @override
  List<Object> get props => [user];
}
class UserError extends UserState {
  final String message;
  const UserError(this.message);

  @override
  List<Object> get props => [message];
}
```

**`lib/features/user/presentation/bloc/user_bloc.dart`**
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_user_profile.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final GetUserProfile getUserProfile;

  UserBloc({required this.getUserProfile}) : super(UserInitial()) {
    on<FetchUserProfile>((event, emit) async {
      emit(UserLoading());
      final failureOrUser = await getUserProfile(event.userId);
      failureOrUser.fold(
        (failure) => emit(const UserError('Failed to fetch user')),
        (user) => emit(UserLoaded(user)),
      );
    });
  }
}
```

**`lib/features/user/presentation/pages/user_profile_page.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/user_bloc.dart';
import '../bloc/user_event.dart';
import '../bloc/user_state.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Trigger event on load
    context.read<UserBloc>().add(FetchUserProfile(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('User Profile')),
      body: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is UserLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is UserLoaded) {
            return Center(child: Text('Welcome, ${state.user.name}'));
          } else if (state is UserError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

---

## 6. Dependency Injection Entry Point

### `lib/injection_container.dart`
```dart
import 'package:get_it/get_it.dart';
import 'features/user/data/datasources/user_remote_data_source.dart';
import 'features/user/data/repositories/user_repository_impl.dart';
import 'features/user/domain/repositories/user_repository.dart';
import 'features/user/domain/usecases/get_user_profile.dart';
import 'features/user/presentation/bloc/user_bloc.dart';

final sl = GetIt.instance;

void init() {
  // Blocs
  sl.registerFactory(() => UserBloc(getUserProfile: sl()));

  // Use cases
  sl.registerLazySingleton(() => GetUserProfile(sl()));

  // Repositories
  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(remoteDataSource: sl()),
  );

  // Data Sources
  sl.registerLazySingleton<UserRemoteDataSource>(
    () => UserRemoteDataSourceImpl(),
  );
}
```

---

## 7. Why This Implementation Succeeds Clean Architecture Standards

* **Framework Independence:** The entire `domain/` layer can be extracted and run in a pure Dart CLI environment without installing Flutter dependencies.
* **Replaceability:** If you decide to swap Supabase with Firebase or Appwrite, you only rewrite classes inside `data/datasources/` and `data/models/`. Zero lines of code change in `domain/` or `presentation/`.
* **Strict State Isolation:** The UI never calls repositories or data sources directly. UI components exclusively dispatch events to BLoCs, which call Use Cases, which consult Repositories.