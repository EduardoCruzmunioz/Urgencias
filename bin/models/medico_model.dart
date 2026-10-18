// Quicktype generó la clase M1 (especialidad, nombre) para cada médico.
// Aquí se llama Medico y lleva además el id, que en Firebase es la clave
// del nodo (m1, m2, m3), no un campo del JSON.
class Medico {
  final String id;
  final String especialidad;
  final String nombre;

  Medico({required this.id, required this.especialidad, required this.nombre});

  factory Medico.fromJson(String id, Map<String, dynamic> json) => Medico(
    id: id,
    especialidad: json["especialidad"],
    nombre: json["nombre"],
  );

  Map<String, dynamic> toJson() => {
    "especialidad": especialidad,
    "nombre": nombre,
  };

  @override
  String toString() {
    return 'Nombre del médico: $nombre\n'
        'Especialidad: $especialidad\n';
  }
}
