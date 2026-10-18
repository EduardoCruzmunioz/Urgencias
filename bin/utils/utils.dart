import 'dart:io';

void limpiarPantalla() {
  for (var i = 0; i < 50; i++) {
    print('');
  }
}

void pulsaParaContinuar() {
  stdout.write('\nPulsa ENTER para continuar...');
  stdin.readLineSync();
}
