# Global options
complete -c protei-daemon -s h -l help -d "Show help message and exit"
complete -c protei-daemon -l version -d "Show program's version number"

# Подкоманды protei-daemon
complete -c protei-daemon -f -a "list" -d "Get services list"
complete -c protei-daemon -f -a "get_caps" -d "Receiving current protei-daemon capabilities"
complete -c protei-daemon -f -a "state" -d "Get protei-daemon full state (including info about services)"
complete -c protei-daemon -f -a "status" -d "Receiving status of the service"
complete -c protei-daemon -f -a "start" -d "Starts the service"
complete -c protei-daemon -f -a "stop" -d "Stops the service"
complete -c protei-daemon -f -a "set_soft_shutdown_wait" -d "Moving service to WAIT_FOR_SHUTDOWN state"
complete -c protei-daemon -f -a "restart" -d "Restarts the service"
complete -c protei-daemon -f -a "install" -d "Installing service to system"
complete -c protei-daemon -f -a "uninstall" -d "Uninstalling service from system"
complete -c protei-daemon -f -a "reinstall" -d "Reinstall service (regenerates init script)"
complete -c protei-daemon -f -a "enable" -d "Enabling service on boot"
complete -c protei-daemon -f -a "is-enabled" -d "Checking if service is enabled to start on boot"
complete -c protei-daemon -f -a "disable" -d "Disabling service on boot"
complete -c protei-daemon -f -a "uptime" -d "Get service process uptime"
complete -c protei-daemon -f -a "command" -d "Execute service command"
complete -c protei-daemon -f -a "reload" -d "Reload service"
complete -c protei-daemon -f -a "get_service_config" -d "Receiving service config in JSON format"
complete -c protei-daemon -f -a "get_service_param" -d "Receiving one parameter of service config"
complete -c protei-daemon -f -a "rescan_services" -d "Rescan services on file system"
complete -c protei-daemon -f -a "reinstall_all" -d "Reinstall all services"
complete -c protei-daemon -f -a "ping" -d "Check for manager working"
complete -c protei-daemon -f -a "boot" -d "Start services on boot (for unsupported distribs)"
complete -c protei-daemon -f -a "halt" -d "Stop services on halt (for unsupported distribs)"
complete -c protei-daemon -f -a "cmd_list" -d "Print all supported commands divided by spaces"

# Функция для получения списка сервисов.
function __fish_protei_daemon_get_services
    # Получаем список сервисов; если команда вернёт ошибку – подавляем её вывод.
    #set -l services (sudo protei-daemon list 2>/dev/null)
    #for service in $services
    #    echo $service
    #end
    echo protei-config-provider
    echo protei-config-provider.protei
    echo protei-uc-access-layer-web-go
    echo protei-uc-address-book-srv
    echo protei-uc-asbc-gw-srv
    echo protei-uc-auth-gateway
    echo protei-uc-avatar-manager-srv
    echo protei-uc-call-srv
    echo protei-uc-community-manager-api-gw
    echo protei-uc-community-manager-srv
    echo protei-uc-group-srv
    echo protei-uc-in-srv
    echo protei-uc-outlook-integration-srv
    echo protei-uc-plugin-srv
    echo protei-uc-post-srv
    echo protei-uc-presence
    echo protei-uc-push-srv
    echo protei-uc-reactions-srv
    echo protei-uc-route-srv
    echo protei-uc-seaweed-filer
    echo protei-uc-seaweed-master
    echo protei-uc-seaweed-volume
    echo protei-uc-snapshot
    echo protei-uc-user-db-sync-srv
    echo protei-uc-user-message-store-srv
    echo protei-uc-vcs-adapter
end

# Основное автодополнение для подкоманд, которые не требуют аргумента сервиса.
# Здесь перечислены те подкоманды, для которых список сервисов не нужен.
complete -c protei-daemon -f -n 'not __fish_seen_subcommand_from' \
    -a "list get_caps state ping boot halt cmd_list" -d "Подкоманда protei-daemon (без имени сервиса)"

# Список подкоманд, для которых требуется указание сервиса.
# Измените или дополните список по необходимости.
set -l service_commands "status start stop restart install uninstall enable is-enabled disable uptime command reload get_service_config get_service_param"

# Для каждой подкоманды из списка предлагаем автодополнение имен сервисов.
for sub in $service_commands
    complete -c protei-daemon -n "__fish_seen_subcommand_from $sub" \
        -a "(__fish_protei_daemon_get_services)" -d "Имя сервиса"
end
