# @api private
class postgresql::server::reload {
  postgresql::server::instance::reload { 'main':
    service_status => $postgresql::server::_service_status,
    service_reload => $postgresql::server::_service_reload,
  }
}
