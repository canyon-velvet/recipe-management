# Recipe Manager

One place for all the recipes I've saved, an assistant that helps me pick what to cook from them, and a weekly
meal plan that writes my grocery list for me.

**Plan the week and get the grocery list**

[plan_the_week.webm](https://github.com/user-attachments/assets/da4b664c-0192-4e9a-9674-ef3162c98058)


**Import a recipe from a link**

[import_recipe.webm](https://github.com/user-attachments/assets/4f91e8ca-434b-446f-8be3-c96b4ce65d06)


**Ask the assistant: cooking questions, recipe ideas, imports and preferences**

[ask_the_assistant.webm](https://github.com/user-attachments/assets/f5f040cc-9a88-4b27-b643-746247334c4e)


## The problem

My saved recipes were scattered everywhere: bookmarked cooking websites, posts saved on social
media, and several different recipe apps. When it was time to decide what to cook, I had to
remember where each one lived. When it was time to shop, I had to open every recipe and copy the
ingredients by hand.

I wanted one website that collects every recipe I care about, helps me decide what to cook, and
turns a week of meals into a shopping list.

## What it does

- **Import a recipe from a link.** Paste a link to a recipe site such as 下厨房, or paste the
  recipe's text. It's read in the background, and Claude tidies it up: ingredients split into
  amounts and units, steps in order, tags and the author's tips. It then waits in a Draft box
  until I review and save it. I can also type a recipe in by hand.
- **Browse my collection.** Tag recipes by meal, cuisine, diet and convenience, then browse them
  from a category sidebar or search by name.
- **Plan the week.** Drop recipes into breakfast, lunch, dinner or snack for each day.
- **Get the grocery list for free.** Ingredients from the week's meals are gathered into one
  list, grouped by store aisle in shopping order. I can rename, reorder and add aisles.
- **Skip what I already have.** Mark items I already have at home, and they stay marked
  even when the meal plan changes.
- **Ask the assistant.** A chat panel (✦) beside any page. It answers cooking questions,
  recommends recipes from my own collection with a reason for each, and imports a recipe from a
  link I paste. When I mention something like "we're vegetarian", it offers to save it to my
  preferences, which its recommendations follow from then on. Behind it, a router on Claude
  Haiku answers itself or hands over to a Recommend or Import specialist.

## A note on language

The interface is in English and Simplified Chinese, and the 🌐 button switches between them.
I built this for my own household, where we cook from both Chinese and American recipes.

## Deploy

It runs on [Render](https://render.com), described in [`render.yaml`](render.yaml):

- **Web service** (Docker): Thruster in front of Puma.
- **Background worker**: Sidekiq, which runs imports and the assistant's replies.
- **Postgres** and **Key Value** (Redis): for jobs, live updates and rate limits. Both are reachable only from the
  services.

The smallest paid plans come to about $30 a month, plus Claude usage.

1. In Render, choose **New → Blueprint** and pick this repository.
2. It asks for `RAILS_MASTER_KEY` twice, for the web service and the worker: paste the contents of
   `config/master.key` into both. That file is never committed; keep it safe.
3. Once the first deploy is live, open the web service's **Shell**, run `bin/rails console`, and create your admin
   account. The password is typed at a hidden prompt, so it isn't kept in the console's history:
   ```ruby
   User.create!(username: "me", password: IO.console.getpass("Password: "), admin: true)
   ```
4. Log in, then invite people from the account menu → **Invites**. Signing up is by invite link only.

To use your own domain, add it in Render, then set `APP_HOSTS` on the web service (comma-separated) so the app
accepts it.

Built with Ruby on Rails.
