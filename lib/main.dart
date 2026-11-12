

import 'package:camera/camera.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CameraDemoApp());
}

class CameraDemoApp extends StatelessWidget {
  const CameraDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prueba de cámara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const CameraHomePage(),
    );
  }
}

class CameraHomePage extends StatefulWidget {
  const CameraHomePage({super.key});

  @override
  State<CameraHomePage> createState() => _CameraHomePageState();
}

class _CameraHomePageState extends State<CameraHomePage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  XFile? _capturedImage;
  bool _initializing = true;
  bool _takingPicture = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('no_camera', 'No se encontró ninguna cámara disponible.');
      }

      final selectedIndex = cameraIndex ?? _preferredCameraIndex();
      final camera = _cameras[selectedIndex.clamp(0, _cameras.length - 1).toInt()];
      final oldController = _controller;
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await oldController?.dispose();
      await _controller!.initialize();
    } on CameraException catch (e) {
      _error = _cameraErrorMessage(e);
    } catch (e) {
      _error = 'No se pudo iniciar la cámara: $e';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  int _preferredCameraIndex() {
    final backIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    return backIndex >= 0 ? backIndex : 0;
  }

  String _cameraErrorMessage(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
        return 'Permiso de cámara denegado. Autoriza el acceso en los ajustes del dispositivo o navegador.';
      case 'CameraAccessDeniedWithoutPrompt':
        return 'El navegador bloqueó la cámara. Revisa los permisos del sitio.';
      case 'CameraAccessRestricted':
        return 'El acceso a la cámara está restringido en este dispositivo.';
      default:
        return 'Error de cámara (${e.code}): ${e.description ?? 'sin detalle'}';
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _takingPicture) return;

    setState(() => _takingPicture = true);
    try {
      final image = await controller.takePicture();
      if (mounted) setState(() => _capturedImage = image);
    } on CameraException catch (e) {
      _showMessage('No se pudo tomar la fotografía: ${e.description ?? e.code}');
    } catch (e) {
      _showMessage('Error al capturar la imagen: $e');
    } finally {
      if (mounted) setState(() => _takingPicture = false);
    }
  }

  Future<void> _savePicture() async {
    final image = _capturedImage;
    if (image == null || _saving) return;

    setState(() => _saving = true);
    try {
      final bytes = await image.readAsBytes();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final filename = 'captura_$timestamp';

      // FileSaver descarga el archivo en web y lo guarda/expone para guardar en dispositivos.
      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: 'jpg',
        mimeType: MimeType.jpeg,
      );
      _showMessage(kIsWeb
          ? 'Se inició la descarga de la fotografía.'
          : 'Fotografía enviada al sistema de guardado del dispositivo.');
    } catch (e) {
      _showMessage('No se pudo guardar la fotografía: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de cámara'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Cambiar cámara',
              onPressed: _initializing
                  ? null
                  : () {
                      final current = _cameras.indexOf(controller!.description);
                      _initializeCamera(cameraIndex: (current + 1) % _cameras.length);
                    },
              icon: const Icon(Icons.cameraswitch),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        color: Colors.black12,
                        child: _buildPreview(controller),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_capturedImage != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Captura lista para guardar')),
                        TextButton.icon(
                          onPressed: () => setState(() => _capturedImage = null),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Repetir'),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text('Alinea la cámara y toma una fotografía.'),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _initializing || _takingPicture || controller?.value.isInitialized != true
                              ? null
                              : _takePicture,
                          icon: _takingPicture
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.camera_alt),
                          label: Text(_takingPicture ? 'Capturando...' : 'Tomar foto'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturedImage == null || _saving ? null : _savePicture,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_alt),
                          label: Text(_saving ? 'Guardando...' : 'Guardar captura'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? 'En web, la captura se descarga como archivo JPG.'
                        : 'En móvil, el sistema permite guardar la captura en el dispositivo.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(CameraController? controller) {
    if (_initializing) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_capturedImage != null) {
      return FutureBuilder<Uint8List>(
        future: _capturedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No se pudo mostrar la captura.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
        },
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('La cámara no está disponible.'));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}
