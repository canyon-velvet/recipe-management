# Recipe Manager

A personal recipe collection that gathers recipes saved from many places, plans the week's meals, and builds the grocery list from them.

## Recipes

**Recipe**:
A dish a user has saved: its ingredients, ordered steps, and tags. Every recipe belongs to one user.
_Avoid_: Dish, post

**Recipe link**:
The address of the exact page or post a recipe was taken from.
_Avoid_: Original link, source link

**Source**:
The website, app, publication, or person a recipe came from, such as Yummy Toddler Food, 下厨房, a cookbook, or Mom. Each user has their own sources. Many recipes share one source.
_Avoid_: Site, platform, author, origin

## Ingredients

**Ingredient**:
A food item a user cooks with, such as eggs or soy sauce. Each user has their own ingredients, and each ingredient sits in one aisle.
_Avoid_: Item, product

**Aisle**:
A broad section of a grocery store, such as Produce or Dairy & Eggs, used to group the grocery list in shopping order. Each user has their own aisles, which stay general and few, never one per ingredient.
_Avoid_: Ingredient category, category, ingredient type

## Importing

**Import**:
Turning a recipe link or pasted recipe text into a draft, from the Import page or by sending a link to the assistant. It runs in the background while the user does other things.
_Avoid_: Scrape, parse, fetch

**Draft**:
A recipe produced by an import that the user hasn't saved yet. The user reviews and edits it before it becomes a recipe.
_Avoid_: Preview, pending recipe

**Draft box**:
The place where a user's drafts wait until each one is saved as a recipe or discarded.
_Avoid_: Inbox, imports page, queue

## Assistant

**Assistant**:
The chat helper in the side panel that recommends recipes from the user's own collection and imports recipe links.
_Avoid_: Chatbot, bot, AI

**Conversation**:
One chat between a user and the assistant, made of messages from both. The panel shows the newest; "New chat" starts another.
_Avoid_: Thread, session, chat log

**Specialist**:
The part of the assistant that handles one kind of request, such as recommending recipes. The assistant hands a message to a specialist when it needs one, and keeps the follow-ups with it.
_Avoid_: Sub-agent, bot

**Preference**:
A short fact about what a user eats, in one of five categories: diet, likes, dislikes, avoid, or household (who they cook for). The assistant follows preferences when it recommends recipes, and when it hears a new one in the chat it offers to save it; only the user can save it. A recipe containing something the user avoids can still be recommended, but always with a clear warning, so the user decides.
_Avoid_: Profile, setting, restriction

## Accounts

**Invite**:
A link an admin sends to let one person sign up. Signing up is only possible with an invite; each works once and expires after a week.
_Avoid_: Invitation code, referral
