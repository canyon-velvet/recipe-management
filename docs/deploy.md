# Deploy

It runs on [Render](https://render.com), described in [`render.yaml`](../render.yaml):

- **Web service** (Docker): Thruster in front of Puma.
- **Background worker**: Sidekiq, which runs imports and the assistant's replies.
- **Postgres** and **Key Value** (Redis): for jobs, live updates and rate limits. Both are reachable only from the
  services.

The smallest paid plans come to about $30 a month, plus Claude usage.

## The first time

1. In Render, choose **New → Blueprint** and pick this repository.
2. It asks for `RAILS_MASTER_KEY` twice, for the web service and the worker: paste the contents of
   `config/credentials/production.key` into both. Production has its own credentials
   (`config/credentials/production.yml.enc`, edited with `bin/rails credentials:edit --environment production`), apart
   from development's `config/master.key`. Key files are never committed; keep them in a password manager.
3. Once the first deploy is live, open the web service's **Shell**, run `bin/rails console`, and create your admin
   account. Nobody can sign up without an invite, and only an admin can make one, so the first account has to be made
   here. The password is typed at a hidden prompt, so it isn't kept in the console's history:
   ```ruby
   User.create!(username: "me", password: IO.console.getpass("Password: "), admin: true)
   ```
4. Log in, then invite people from the account menu → **Invites**. Signing up is by invite link only.
5. In the [Anthropic console](https://console.anthropic.com), set a monthly spend limit on the API key. The app limits
   each user's imports and assistant messages, but nothing caps the total.

To use your own domain, add it in Render, then set `APP_HOSTS` on the web service (comma-separated) so the app
accepts it.

## Each release

Deploys are manual: a merge to main doesn't deploy. Use **Manual Deploy** on both services, **the web service first,
then the worker**. Only the web service migrates the database (its pre-deploy command), so a worker that went first
would run the new code on the old database, and imports and the assistant's replies would fail until the web service
caught up.
