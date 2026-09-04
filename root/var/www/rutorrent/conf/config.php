<?php

// for snoopy client (used for RSS/torrent-link fetching)
$httpUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';
$httpTimeOut = 30;
$httpUseGzip = true;

// for xmlrpc actions
$rpcTimeOut = 5;
$rpcLogCalls = false;
$rpcLogFaults = true;

// for php
$phpUseGzip = false;
$phpGzipLevel = 2;

// Rand for schedulers start, +0..X seconds
$schedule_rand = 10;

// Path to log file (comment or leave blank to disable logging)
$log_file = '/config/log/rutorrent.log';
$do_diagnostic = true;

// rTorrent is on the same container as ruTorrent
$localHostedMode = true;

$cachedPluginLoading = false;
$pluginMinification = true;

$saveUploadedTorrents = true;
$overwriteUploadedTorrents = false;

// Upper available directory. Absolute path with trail slash.
$topDirectory = '/';
$forbidUserSettings = false;

// For web->rtorrent link through unix domain socket.
// This is OUR socket path from Step 3's service-rtorrent, not the
// /var/run/rtorrent/scgi.socket path crazymax's own build uses.
$scgi_port = 0;
$scgi_host = "unix:///dev/shm/rtorrent.sock";

$XMLRPCMountPoint = "/RPC2";
// Can't be greater than 327625*1024 due to a limitation in libtorrent's
// ResourceManager::set_max_upload_unchoked function.
$throttleMaxSpeed = 327625 * 1024;

// Empty string = ruTorrent auto-detects via its own internal lookup
$pathToExternals = array(
    "php"    => '',
    "curl"   => '',
    "gzip"   => '',
    "id"     => '',
    "stat"   => '',
    "python" => '',
);

$localhosts = array(
    "::1",
    "127.0.0.1",
    "localhost",
);

// Path to user profiles
$profilePath = '/config/rutorrent/share';
$profileMask = 0770;

// Temp directory. If null, autodetect is used.
$tempDirectory = null;

$canUseXSendFile = false;

$locale = 'UTF8';

$enableCSRFCheck = false;
$enabledOrigins = array();
