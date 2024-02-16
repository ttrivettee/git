#!/bin/sh

test_description="test fetching through http via unix domain socket"

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh

test -z "$NO_UNIX_SOCKETS" || {
	skip_all='skipping http-unix-socket tests, unix sockets not available'
	test_done
}

UDS_TO_TCP_FIFO=uds_to_tcp
TCP_TO_UDS_FIFO=tcp_to_uds
UDS_PID=
TCP_PID=
UDS_SOCKET="$(pwd)/uds.sock"
UNRESOLVABLE_ENDPOINT=http://localhost:4242

start_proxy_unix_to_tcp() {
    local socket_path="$UDS_SOCKET"
    local host=127.0.0.1
    local port=$LIB_HTTPD_PORT

    rm -f "$UDS_TO_TCP_FIFO"
    rm -f "$TCP_TO_UDS_FIFO"
    rm -f "$socket_path"
    mkfifo "$UDS_TO_TCP_FIFO"
    mkfifo "$TCP_TO_UDS_FIFO"
    nc -klU "$socket_path" <tcp_to_uds >uds_to_tcp &
    UDS_PID=$!

    nc "$host" "$port" >tcp_to_uds <uds_to_tcp &
    TCP_PID=$!

    test_atexit 'stop_proxy_unix_to_tcp'
}

stop_proxy_unix_to_tcp() {
    kill "$UDS_PID"
    kill "$TCP_PID"
    rm -f "$UDS_TO_TCP_FIFO"
    rm -f "$TCP_TO_UDS_FIFO"
}

start_httpd
start_proxy_unix_to_tcp

test_expect_success 'setup repository' '
	test_commit foo &&
	git init --bare "$HTTPD_DOCUMENT_ROOT_PATH/repo.git" &&
	git push --mirror "$HTTPD_DOCUMENT_ROOT_PATH/repo.git"
'

# sanity check that we can't clone normally
test_expect_success 'cloning without UDS fails' '
    test_must_fail git clone "$UNRESOLVABLE_ENDPOINT/smart/repo.git" clone
'

test_expect_success 'cloning with UDS succeeds' '
    test_when_finished "rm -rf clone" &&
	test_config_global http.unixsocket "$UDS_SOCKET" &&
	git clone "$UNRESOLVABLE_ENDPOINT/smart/repo.git" clone
'

test_expect_success 'cloning with a non-existent http proxy fails' '
    git clone $HTTPD_URL/smart/repo.git clone &&
    rm -rf clone &&
    test_config_global http.proxy 127.0.0.1:0 &&
    test_must_fail git clone $HTTPD_URL/smart/repo.git clone
'

test_expect_success 'UDS socket takes precedence over http proxy' '
    test_when_finished "rm -rf clone" &&
    test_config_global http.proxy 127.0.0.1:0 &&
    test_config_global http.unixsocket "$UDS_SOCKET" &&
    git clone $HTTPD_URL/smart/repo.git clone
'

test_done
