<?php
/**
 * phpMyAdmin configuration for Docker-in-Docker WordPress environment
 */

declare(strict_types=1);

/**
 * This is needed for cookie based authentication to encrypt password in
 * cookie. Needs to be 32 chars long.
 */
$cfg['blowfish_secret'] = 'wp-dind-phpmyadmin-secret-key-32ch';

/**
 * Server(s) configuration
 */
$i = 0;

// First server - allow arbitrary server selection
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = '';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

/**
 * Allow arbitrary server connection
 */
$cfg['AllowArbitraryServer'] = true;

/**
 * Directories for saving/loading files from server
 */
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';

/**
 * Temporary directory for caching templates and other data
 */
$cfg['TempDir'] = '/var/www/phpmyadmin/tmp/';

/**
 * Session save path
 */
ini_set('session.save_path', '/var/www/phpmyadmin/sessions/');

/**
 * Whether to display icons or text or both icons and text in table row
 * action segment. Value can be either of 'icons', 'text' or 'both'.
 */
$cfg['RowActionType'] = 'icons';

/**
 * Defines whether a user should be displayed a "show all (records)"
 * button in browse mode or not.
 */
$cfg['ShowAll'] = false;

/**
 * Number of rows displayed when browsing a result set.
 */
$cfg['MaxRows'] = 25;

/**
 * Disallow editing of binary fields
 */
$cfg['ProtectBinary'] = false;

/**
 * Default language to use, if not browser-defined or user-defined
 */
$cfg['DefaultLang'] = 'en';

/**
 * How many columns should be used for table display of a database?
 */
$cfg['PropertiesNumColumns'] = 1;

/**
 * Set to true if you want DB-based query history.
 */
$cfg['QueryHistoryDB'] = false;

/**
 * When using DB-based query history, how many entries should be kept?
 */
$cfg['QueryHistoryMax'] = 25;

/**
 * Whether the tracking mechanism creates versions for tables and views automatically.
 */
$cfg['Servers'][$i]['tracking_version_auto_create'] = false;

/**
 * Defines whether the query box should stay on-screen after its submission.
 */
$cfg['RetainQueryBox'] = false;

/**
 * Allow login to any user entered server in cookie based authentication
 */
$cfg['AllowArbitraryServer'] = true;

/**
 * Show PHP information
 */
$cfg['ShowPhpInfo'] = true;

/**
 * Show server information
 */
$cfg['ShowServerInfo'] = true;

/**
 * Show database statistics
 */
$cfg['ShowStats'] = true;

/**
 * Show creation timestamp
 */
$cfg['ShowCreateDb'] = true;

/**
 * Maximum number of databases displayed in database list
 */
$cfg['MaxDbList'] = 100;

/**
 * Maximum number of tables displayed in table list
 */
$cfg['MaxTableList'] = 250;

/**
 * Show hint about the current database
 */
$cfg['ShowHint'] = true;

/**
 * Maximum execution time in seconds (0 for unlimited)
 */
$cfg['ExecTimeLimit'] = 300;

/**
 * Maximum number of characters shown in any non-numeric column on browse view
 */
$cfg['LimitChars'] = 50;

/**
 * You can find more configuration options in the documentation
 * in the doc/ folder or at <https://docs.phpmyadmin.net/>.
 */


/**
 * Maximum upload size (should match PHP settings)
 * Value in bytes (512MB = 512 * 1024 * 1024)
 */
$cfg['UploadMaxFilesize'] = '512M';
$cfg['MaxSizeForInputField'] = 512 * 1024 * 1024;
