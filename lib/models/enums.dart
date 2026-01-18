enum RolUsuario { ADMIN, SOCIO, GERENCIA }
enum EstadoUsuario { PENDIENTE, ACTIVO, BLOQUEADO }
enum EstadoEleccion { BORRADOR, ACTIVA, FINALIZADA }
enum TipoPregunta { OPCION_MULTIPLE, INPUT_NUMERICO }

extension RolUsuarioX on RolUsuario {
  String toShortString() => toString().split('.').last;
}

extension EstadoUsuarioX on EstadoUsuario {
  String toShortString() => toString().split('.').last;
}

extension EstadoEleccionX on EstadoEleccion {
  String toShortString() => toString().split('.').last;
}

extension TipoPreguntaX on TipoPregunta {
  String toShortString() => toString().split('.').last;
}
