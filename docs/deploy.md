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
6. For importing YouTube videos, which Gemini watches, add a Gemini API key to the production credentials, beside
   Anthropic's: `gemini: { api_key: … }`. Without one, a YouTube link is refused with a message saying so. On
   Gemini's free tier, Google may use what's sent (the video's public link and the prompt) to improve its products.

To use your own domain, add it in Render, then set `APP_HOSTS` on the web service (comma-separated) so the app
accepts it.

## Each release

Deploys are manual: a merge to main doesn't deploy. Use **Manual Deploy** on the web service. Its pre-deploy command
migrates the database before the new code goes live.

The exception is a merge that changes `render.yaml`: Render syncs the Blueprint and redeploys the web service by
itself if its settings changed.

### Numbering a release

Each release gets a version number, shown at the foot of the account menu:

1. While it's being made, each pull request adds a line for what it changes to **Unreleased** in
   [`CHANGELOG.md`](../CHANGELOG.md), in words for the people using the app.
2. Before deploying, in one pull request: set the new version in `VERSION`, and rename **Unreleased** to it, with
   the date, leaving an empty **Unreleased** above it. A new feature raises the middle number (1.1.0), a fix the last
   (1.0.1).
3. Once it's merged, tag that pull request's merge commit, and deploy it. Merge nothing else in between, or the
   release would include changes still listed as Unreleased. Optionally, make a GitHub release from the tag, with
   the changelog's lines as its notes.
   ```sh
   git switch main && git pull
   git tag v1.1.0 <merge commit> && git push origin v1.1.0
   ```
   The first release, 1.0.0, is tagged the same way, on the merge that added this.

Admins can see the jobs (queued, running, failed, and retry or discard them) from the account menu →
**Background jobs**.

A deploy gives the jobs still running (an import, an assistant reply) 50 seconds to finish before the old server
stops. One still running after that is usually marked failed within about 10 minutes (`ProcessPrunedError`); until
then it shows as in progress in Background jobs. Meanwhile its draft stays "Reading…", or its reply "Thinking…".
Once it's failed, **Retry** it there (the reply then shows as failed, and the import carries on), or the user can
discard the draft or ask again. Deploying when nobody is importing or chatting avoids it.
