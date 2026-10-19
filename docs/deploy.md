# Deploy

It runs on [Render](https://render.com), described in [`render.yaml`](../render.yaml):

- **Web service** (Docker): Thruster in front of Puma. The background jobs (imports, the assistant's replies) run
  inside it too, with Solid Queue.
- **Postgres**: the data, and also the jobs (Solid Queue), the live updates (Solid Cable) and the rate limits'
  counters (Solid Cache). It's reachable only from the web service.

The smallest paid plans come to about $13 a month, plus the database's storage and Claude usage.

## The first time

1. In Render, choose **New → Blueprint** and pick this repository.
2. It asks for `RAILS_MASTER_KEY`: paste the contents of `config/credentials/production.key`. Production has its own
   credentials (`config/credentials/production.yml.enc`, edited with
   `bin/rails credentials:edit --environment production`), apart from development's `config/master.key`. Key files are
   never committed; keep them in a password manager.
3. Once the first deploy is live, open the web service's **Shell**, run `bin/rails console`, and create your admin
   account. Nobody can sign up without an invite, and only an admin can make one, so the first account has to be made
   here. The password is typed at a hidden prompt, so it isn't kept in the console's history:
   ```ruby
   User.create!(username: "me", password: IO.console.getpass("Password: "), admin: true)
   ```
4. Log in, then invite people from the account menu → **Invites**. Signing up is by invite link only.
5. In the Claude Console, set a monthly spend limit on the workspace the API key belongs to (or on the organization).
   The app limits each user's imports and assistant messages, but nothing caps the total.

To use your own domain, add it in Render, then set `APP_HOSTS` on the web service (comma-separated) so the app
accepts it.

## Each release

Deploys are manual: a merge to main doesn't deploy. Use **Manual Deploy** on the web service. Its pre-deploy command
migrates the database before the new code goes live.

The exception is a merge that changes `render.yaml`: Render syncs the Blueprint and redeploys the web service by
itself if its settings changed.

Admins can see the jobs (queued, running, failed, and retry or discard them) from the account menu →
**Background jobs**.

A deploy gives the jobs still running (an import, an assistant reply) 50 seconds to finish before the old server
stops. One still running after that is marked failed a few minutes later (`ProcessPrunedError`): its draft stays
"Reading…", or its reply "Thinking…". **Retry** it in Background jobs (the reply then shows as failed, and the import
carries on), or the user can discard the draft or ask again. Deploying when nobody is importing or chatting avoids it.
