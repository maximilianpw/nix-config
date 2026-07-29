# Nextcloud Calendar on iPhone

The homelab installs Nextcloud Calendar declaratively and links it from the
Homepage dashboard. Calendar data is available through the existing public
Nextcloud endpoint, so the iPhone does not need an active Tailscale connection.

## Connect Apple Calendar

1. In Nextcloud, open **Personal settings → Security** and create a dedicated
   device password named `iPhone Calendar`.
2. On the iPhone, open **Settings → Apps → Calendar → Calendar Accounts → Add
   Account → Other → Add CalDAV Account**.
3. Enter:
   - **Server:** `nextcloud.maximilian.pw`
   - **User Name:** the Nextcloud username
   - **Password:** the device password from step 1
4. If automatic discovery fails, open **Advanced Settings** and use:
   `https://nextcloud.maximilian.pw/remote.php/dav/principals/users/<username>/`
5. Leave SSL enabled, save the account, and select which Nextcloud calendar is
   the default under **Settings → Apps → Calendar → Default Calendar** if
   desired.

Use one device password per client so access can be revoked independently.

Sources:

- [Nextcloud: Synchronizing with iOS](https://docs.nextcloud.com/server/latest/user_manual/en/groupware/sync_ios.html)
- [Nextcloud: Manage connected browsers and devices](https://docs.nextcloud.com/server/latest/user_manual/en/session_management.html)
