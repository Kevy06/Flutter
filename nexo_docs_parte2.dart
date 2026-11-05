import 'package:flutter/material.dart';

const nomeDesenvolvedor = 'Kevilyn Bitencourt';

void main() => runApp(const MeuApp());

String? validarNome(String? value) {
  final partes = (value ?? '').trim().split(RegExp(r'\s+'));
  return partes.length < 2 ? 'Informe seu nome e sobrenome' : null;
}

String? validarEmail(String? value) {
  final email = (value ?? '').trim();
  final formato = RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)*\.com(?:\.br)?$');
  return formato.hasMatch(email.toLowerCase()) ? null : 'Informe um e-mail válido com .com ou .com.br';
}

String? validarSenha(String? value) {
  return (value ?? '').trim().length < 6
      ? 'A senha deve ter pelo menos 6 caracteres'
      : null;
}

class Usuario {
  const Usuario(this.nome, this.email, this._senha);

  final String nome;
  final String email;
  final String _senha;
}

class BancoDadosLocal {
  final _usuarios = <String, Usuario>{};

  Future<bool> insert(Usuario usuario) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (_usuarios.containsKey(usuario.email)) return false;
    _usuarios[usuario.email] = usuario;
    return true;
  }

  Future<Usuario?> autenticar(String email, String senha) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final usuario = _usuarios[email];
    return usuario?._senha == senha ? usuario : null;
  }

  Future<List<Usuario>> query() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List<Usuario>.unmodifiable(_usuarios.values);
  }
}

class PreferenciasLocais {
  final _valores = <String, bool>{};

  Future<void> salvar(String email, bool escuro, bool avisos) async {
    _valores['$email.temaEscuro'] = escuro;
    _valores['$email.avisos'] = avisos;
  }

  Future<bool> ler(String email, String chave) async {
    return _valores['$email.$chave'] ?? false;
  }
}

final banco = BancoDadosLocal();
final preferencias = PreferenciasLocais();
final tema = ValueNotifier(ThemeMode.light);

ThemeData _temaVisual(Brightness brilho) {
  final cores = ColorScheme.fromSeed(
    seedColor: const Color(0xff6356cf),
    brightness: brilho,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cores,
    scaffoldBackgroundColor: cores.surfaceContainerLow,
    appBarTheme: AppBarTheme(
      backgroundColor: cores.surface,
      foregroundColor: cores.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cores.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cores.primary,
        foregroundColor: cores.onPrimary,
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: tema,
      builder: (context, modo, child) => MaterialApp(
        themeMode: modo,
        darkTheme: _temaVisual(Brightness.dark),
        theme: _temaVisual(Brightness.light),
        title: 'Nexo Docs',
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (_) => const TelaAcesso(),
          '/cadastro': (_) => const TelaAcesso(cadastro: true),
          '/home': (context) {
            final usuario = ModalRoute.of(context)?.settings.arguments;
            return usuario is Usuario
                ? TelaHome(usuario: usuario)
                : const TelaAcesso();
          },
        },
      ),
    );
  }
}

class TelaAcesso extends StatefulWidget {
  const TelaAcesso({super.key, this.cadastro = false});

  final bool cadastro;

  @override
  State<TelaAcesso> createState() => _TelaAcessoState();
}

class _TelaAcessoState extends State<TelaAcesso> {
  final _formKey = GlobalKey<FormState>();

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _escuro = tema.value == ThemeMode.dark;
  bool _ocultarSenha = true;
  bool _avisos = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  Future<void> _enviar() async {
    if (_enviando || !_formKey.currentState!.validate()) return;
    final email = _email.text.trim().toLowerCase();
    final senha = _senha.text;
    final nome = _nome.text.trim();
    final escuro = _escuro;
    final avisos = _avisos;
    setState(() => _enviando = true);

    try {
      if (widget.cadastro) {
        final inserido = await banco.insert(Usuario(nome, email, senha));
        if (!inserido) {
          if (mounted) _avisar('Este e-mail já está cadastrado.');
          return;
        }
        await preferencias.salvar(email, escuro, avisos);
        if (!mounted) return;
        _avisar('Cadastro realizado com sucesso.');
        Navigator.pop(context);
        return;
      }

      final usuario = await banco.autenticar(email, senha);
      if (!mounted) return;
      if (usuario == null) {
        _avisar('E-mail ou senha incorretos.');
        return;
      }
      final temaEscuro = await preferencias.ler(email, 'temaEscuro');
      if (!mounted) return;
      tema.value = temaEscuro ? ThemeMode.dark : ThemeMode.light;
      Navigator.pushReplacementNamed(context, '/home', arguments: usuario);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.cadastro
        ? _temaVisual(_escuro ? Brightness.dark : Brightness.light)
        : Theme.of(context);
    final cores = visual.colorScheme;
    return Theme(
      data: visual,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nexo Docs'),
          actions: [
            if (!widget.cadastro)
              IconButton(
                tooltip: visual.brightness == Brightness.dark
                    ? 'Usar tema claro'
                    : 'Usar tema escuro',
                icon: Icon(visual.brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () {
                  tema.value = visual.brightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: cores.surface,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: CircleAvatar(
                              backgroundColor: cores.primaryContainer,
                              foregroundColor: cores.onPrimaryContainer,
                              radius: 26,
                              child: const Icon(Icons.description_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.cadastro ? 'Crie sua conta' : 'Acesse sua biblioteca',
                            style: visual.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(widget.cadastro
                              ? 'Informe seus dados e personalize sua biblioteca.'
                              : 'Entre para acessar e editar seus documentos.'),
                          const SizedBox(height: 24),
                          if (widget.cadastro) ...[
                            TextFormField(
                              controller: _nome,
                              decoration: const InputDecoration(
                                labelText: 'Nome Completo',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: validarNome,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: validarEmail,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _senha,
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              suffixIcon: IconButton(
                                tooltip: _ocultarSenha ? 'Mostrar senha' : 'Ocultar senha',
                                icon: Icon(_ocultarSenha
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                              ),
                            ),
                            obscureText: _ocultarSenha,
                            validator: validarSenha,
                          ),
                          const SizedBox(height: 20),
                          if (widget.cadastro) ...[
                            DropdownButtonFormField<bool>(
                              initialValue: _escuro,
                              decoration: const InputDecoration(
                                labelText: 'Tema do app',
                                helperText: 'A aparência muda ao selecionar.',
                              ),
                              items: const [
                                DropdownMenuItem(value: false, child: Text('Tema Claro')),
                                DropdownMenuItem(value: true, child: Text('Tema Escuro')),
                              ],
                              onChanged: _enviando
                                  ? null
                                  : (valor) => setState(() => _escuro = valor ?? false),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Avisos de salvamento'),
                              subtitle: const Text('Exibe uma confirmação ao salvar.'),
                              value: _avisos,
                              onChanged: _enviando
                                  ? null
                                  : (valor) => setState(() => _avisos = valor),
                            ),
                          ],
                          ElevatedButton(
                            onPressed: _enviando ? null : _enviar,
                            child: Text(_enviando
                                ? 'Aguarde...'
                                : widget.cadastro ? 'Cadastrar' : 'Entrar'),
                          ),
                          if (!widget.cadastro)
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/cadastro'),
                              child: const Text('Cadastre-se'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TelaHome extends StatefulWidget {
  const TelaHome({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<TelaHome> createState() => _TelaHomeState();
}

class _TelaHomeState extends State<TelaHome> {
  final _documentos = <String>[
    'Anote aqui as ideias da próxima reunião.',
    'Liste aqui as etapas do seu projeto.',
  ];
  final _editor = TextEditingController();
  int _selecionado = 0;
  bool _modoLeitura = false;

  @override
  void initState() {
    super.initState();
    _editor.text = _documentos.first;
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  void _abrir(int indice) {
    setState(() => _selecionado = indice);
    _editor.text = _documentos[indice];
  }

  void _novo() {
    _documentos.add('');
    _abrir(_documentos.length - 1);
    setState(() => _modoLeitura = false);
  }

  Future<void> _salvar() async {
    _documentos[_selecionado] = _editor.text;
    final avisos = await preferencias.ler(widget.usuario.email, 'avisos');
    if (!mounted || !avisos) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Documento salvo nesta sessão.')),
    );
  }

  void _mostrar(String titulo, Widget conteudo) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: conteudo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarPreferencias() async {
    final email = widget.usuario.email;
    final escuro = await preferencias.ler(email, 'temaEscuro');
    final avisos = await preferencias.ler(email, 'avisos');
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _mostrar(
      'Preferências do usuário',
      Text('Tema: ${escuro ? "Escuro" : "Claro"}\n'
          'Avisos: ${avisos ? "Ativados" : "Desativados"}'),
    );
  }

  Future<void> _mostrarUsuarios() async {
    final usuarios = await banco.query();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _mostrar(
      'Usuários no banco local',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final usuario in usuarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('${usuario.nome}\n${usuario.email}'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context);
    final cores = visual.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexo Docs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              tema.value = ThemeMode.light;
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: cores.primaryContainer,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          color: cores.onPrimaryContainer, size: 30),
                      const SizedBox(height: 12),
                      Text('Olá, ${widget.usuario.nome}!',
                          style: visual.textTheme.headlineSmall?.copyWith(
                            color: cores.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 4),
                      Text('Organize, leia e edite seus documentos.',
                          style: TextStyle(color: cores.onPrimaryContainer)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Sua conta', style: visual.textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Preferências do usuário'),
                  subtitle: const Text('Consulte o tema e os avisos da conta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _mostrarPreferencias,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Usuários no banco local'),
                  subtitle: const Text('Consulte os cadastros desta execução'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _mostrarUsuarios,
                ),
              ),
              const SizedBox(height: 16),
              Text('Minha biblioteca',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Text('Abra um documento ou comece um novo.'),
              const SizedBox(height: 12),
              for (var i = 0; i < _documentos.length; i++)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text('Documento ${i + 1}'),
                    selected: i == _selecionado,
                    selectedTileColor: cores.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    trailing: i == _selecionado
                        ? const Icon(Icons.check_circle_outline)
                        : null,
                    onTap: () => _abrir(i),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _editor,
                minLines: 8,
                maxLines: 12,
                readOnly: _modoLeitura,
                decoration: InputDecoration(
                  labelText: 'Documento ${_selecionado + 1}',
                  alignLabelWithHint: true,
                  helperText: _modoLeitura ? 'Modo leitura' : 'Modo edição',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _novo,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo documento'),
                  ),
                  FilledButton(
                    onPressed: _modoLeitura ? null : _salvar,
                    child: const Text('Salvar'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _modoLeitura = !_modoLeitura);
                    },
                    child: Text(_modoLeitura ? 'Modo Edição' : 'Modo Leitura'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: const Center(child: Text('Desenvolvedora: $nomeDesenvolvedor')),
      ),
    );
  }
}
