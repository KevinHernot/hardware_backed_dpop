import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hardware_backed_dpop/hardware_backed_dpop.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _hardwareBackedDpop = HardwareBackedDpop();
  final _prettyJsonEncoder = const JsonEncoder.withIndent('  ');

  DpopBindingMaterial? _binding;
  String? _proof;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBinding());
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _loadBinding() {
    return _run(() async {
      final binding = await _hardwareBackedDpop.getOrCreateBinding();
      if (!mounted) {
        return;
      }
      setState(() {
        _binding = binding;
      });
    });
  }

  Future<void> _rotateBinding() {
    return _run(() async {
      final binding = await _hardwareBackedDpop.rotateBinding();
      if (!mounted) {
        return;
      }
      setState(() {
        _binding = binding;
        _proof = null;
      });
    });
  }

  Future<void> _buildProof() {
    return _run(() async {
      final proof = await _hardwareBackedDpop.buildProof(
        htu: 'https://api.example.com/v1/messages',
        htm: 'POST',
        accessToken: 'demo-access-token',
        nonce: 'demo-nonce',
      );
      final binding = await _hardwareBackedDpop.getExistingBinding();
      if (!mounted) {
        return;
      }
      setState(() {
        _binding = binding;
        _proof = proof;
      });
    });
  }

  Future<void> _deleteBinding() {
    return _run(() async {
      await _hardwareBackedDpop.deleteBinding();
      if (!mounted) {
        return;
      }
      setState(() {
        _binding = null;
        _proof = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bindingJson = _binding == null
        ? 'No binding loaded yet.'
        : _prettyJsonEncoder.convert(_binding!.toJson());

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C5D99)),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('hardware_backed_dpop example'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hardware-backed DPoP binding + proof signing demo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'The private key stays in the platform keystore. The app only receives the public binding material and the signed proof.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _loadBinding,
                    child: const Text('Load / create binding'),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy ? null : _rotateBinding,
                    child: const Text('Rotate binding'),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy ? null : _buildProof,
                    child: const Text('Build proof'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _deleteBinding,
                    child: const Text('Delete binding'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_busy) const LinearProgressIndicator(),
              if (_busy) const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Binding material',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(bindingJson),
              const SizedBox(height: 24),
              Text(
                'Signed proof',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(_proof ?? 'No proof generated yet.'),
            ],
          ),
        ),
      ),
    );
  }
}
