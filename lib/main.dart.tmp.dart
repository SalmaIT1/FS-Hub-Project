class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize chat services at the root level so they persist across routes
    const apiBaseUrl = 'http://localhost:8080';
    const wsBaseUrl = 'ws://localhost:8080/ws';

    Future<String> getToken() async {
      final token = await AuthService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No authentication token available');
      }
      return token;
    }

    return MultiProvider(
      providers: [
        Provider<ChatRestClient>(create: (_) => ChatRestClient(baseUrl: apiBaseUrl, tokenProvider: getToken)),
        Provider<ChatSocketClient>(create: (_) => ChatSocketClient(wsUrl: wsBaseUrl, tokenProvider: getToken)),
        Provider<UploadService>(create: (_) => UploadService(baseUrl: apiBaseUrl, tokenProvider: getToken)),
        ProxyProvider3<ChatRestClient, ChatSocketClient, UploadService, ChatRepository>(
          update: (_, rest, socket, uploads, __) => ChatRepository(rest: rest, socket: socket, uploads: uploads),
        ),
        ChangeNotifierProxyProvider<ChatRepository, ChatController>(
          create: (context) => ChatController(repository: Provider.of<ChatRepository>(context, listen: false)),
          update: (_, repo, controller) => controller ?? ChatController(repository: repo),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            title: 'FS Hub',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.glassLightTheme,
            darkTheme: AppTheme.glassDarkTheme,
            themeMode: currentMode,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const GlassLoginPage(),
              '/home': (context) => const HomePage(),
              '/employees': (context) => const EmployeesListPage(),
              '/notifications': (context) => const NotificationCenterPage(),
              '/chat': (context) => const new_chat.ConversationListPage(),
              '/demands': (context) => const DemandsListPage(),
            },
            onGenerateRoute: (settings) {
              // Handle routes with parameters
              if (settings.name == AppRoutes.employeeDetail) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['employee'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => EmployeeDetailPage(employee: args['employee']),
                  );
                }
              } else if (settings.name == AppRoutes.addEmployee) {
                return MaterialPageRoute(
                  builder: (context) => const AddEditEmployeePage(),
                );
              } else if (settings.name == AppRoutes.editEmployee) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['employee'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => AddEditEmployeePage(employee: args['employee']),
                  );
                }
              } else if (settings.name == AppRoutes.myProfile) {
                return MaterialPageRoute(
                  builder: (context) => const MyProfilePage(),
                );
              } else if (settings.name == AppRoutes.createDemand) {
                return MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Create Demand')),
                    body: const Center(child: Text('Create Demand page not implemented yet')),
                  ),
                );
              } else if (settings.name == AppRoutes.demandDetail) {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null && args['demand'] != null) {
                  return MaterialPageRoute(
                    builder: (context) => DemandDetailPage(demand: args['demand']),
                  );
                }
              } else if (settings.name == '/chat_thread') {
                final args = settings.arguments as Map<String, dynamic>?;
                String conversationId = '';
                ConversationEntity? conversation;
                if (args != null) {
                  if (args['conversationId'] != null) {
                    conversationId = args['conversationId'].toString();
                  } else if (args['conversation'] is Map && args['conversation']['id'] != null) {
                    conversationId = args['conversation']['id'].toString();
                  }
                  if (args['conversation'] is ConversationEntity) {
                    conversation = args['conversation'] as ConversationEntity;
                  }
                }
                
                return MaterialPageRoute(
                  builder: (context) => conversationId.isNotEmpty
                    ? new_chat.ChatThreadPage(
                        conversationId: conversationId,
                        conversation: conversation,
                      )
                    : const new_chat.ConversationListPage(),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF5F7FA),
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF5F7FA),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFF5F7FA),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF888888),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC9A24D),
        brightness: Brightness.dark,
        background: const Color(0xFF0A0A0A),
        surface: const Color(0xFF1A1A1A),
        primary: const Color(0xFFC9A24D),
        onPrimary: const Color(0xFFF5F7FA),
        onSurface: const Color(0xFFF5F7FA),
        onBackground: const Color(0xFFF5F7FA),
      ),
    );
  }
}
