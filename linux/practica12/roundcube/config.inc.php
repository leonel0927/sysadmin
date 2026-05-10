<?php
$config['product_name'] = 'Correo Reprobados.com';
$config['default_host'] = 'ssl://mailserver';
$config['default_port'] = 993;
$config['smtp_server']  = 'tls://mailserver';
$config['smtp_port']    = 587;
$config['smtp_user']    = '%u';
$config['smtp_pass']    = '%p';
$config['username_domain']    = 'reprobados.com';
$config['mail_domain']        = 'reprobados.com';
$config['session_lifetime']   = 30;
$config['skin']               = 'elastic';
$config['language']           = 'es_ES';
$config['imap_conn_options']  = array(
    'ssl' => array(
        'verify_peer'       => false,
        'verify_peer_name'  => false,
        'allow_self_signed' => true
    )
);
$config['smtp_conn_options']  = array(
    'ssl' => array(
        'verify_peer'       => false,
        'verify_peer_name'  => false,
        'allow_self_signed' => true
    )
);
