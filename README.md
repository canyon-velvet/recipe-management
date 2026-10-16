# Recipe Manager

[![CI](https://github.com/canyon-velvet/recipe-management/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/canyon-velvet/recipe_management/actions/workflows/ci.yml)
[![Ruby 3.4](https://img.shields.io/badge/Ruby-3.4-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)
[![Rails 8.1](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)](https://rubyonrails.org)
[![Hotwire](https://img.shields.io/badge/Hotwire-Turbo%20%2B%20Stimulus-5CD8E5?logo=hotwire&logoColor=white)](https://hotwired.dev)
[![LLM: Claude](https://img.shields.io/badge/LLM-Claude-D97757?logo=claude&logoColor=white)](https://www.anthropic.com/claude)
[![Deployed on Render](https://img.shields.io/badge/Deployed%20on-Render-46E3B7?logo=render&logoColor=white)](https://recipe-management-web-72dj.onrender.com)

It's deployed on Render.

One place for all the recipes I've saved, an assistant that helps me pick what to cook from them, and a weekly
meal plan that writes my grocery list for me.


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
