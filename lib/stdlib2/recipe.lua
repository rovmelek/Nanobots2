--- Recipe and technology edits for the data stage: add or replace an ingredient, unlock a recipe with a technology.
--- Derived from stdlib2 2.1.0 (https://github.com/rovmelek/stdlib2 @ e39ed5a): stdlib/data/recipe.lua,
--- stdlib/data/technology.lua (add_effect).
--- Copyright (c) 2016, Afforess. ISC license, see lib/stdlib2/LICENSE. Trimmed to what Nanobots2 uses.
---
--- Everything here takes prototype names. A missing prototype is logged and skipped, so a compatibility edit for a mod
--- that is not there (or renamed an item) does not break loading.
local flib_prototypes = require('__Nanobots2__.lib.flib.prototypes')

local Recipe = {}

--- 'fluid' or 'item' for the name of an ingredient, nil when it does not exist. Fluids are checked first.
--- @param name string
--- @return string|nil
local function ingredient_type(name)
    if flib_prototypes.find('fluid', name) then
        return 'fluid'
    elseif flib_prototypes.find('item', name) then
        return 'item'
    end
end

--- @param name string
--- @return table|nil
local function find_recipe(name)
    local recipe = data.raw.recipe[name]
    if not recipe then
        log('Recipe not found: ' .. name)
    end
    return recipe
end

--- Add an ingredient to a recipe.
--- @param recipe_name string
--- @param name string the item or fluid
--- @param amount number? defaults to 1
function Recipe.add_ingredient(recipe_name, name, amount)
    local recipe = find_recipe(recipe_name)
    local kind = recipe and ingredient_type(name)
    if recipe and not kind then
        log('Ingredient not found: ' .. name)
    end
    if recipe and kind then
        recipe.ingredients = recipe.ingredients or {}
        recipe.ingredients[#recipe.ingredients + 1] = {type = kind, name = name, amount = amount or 1}
    end
end

--- Replace the first ingredient called `old_name` with another, keeping the amount.
--- @param recipe_name string
--- @param old_name string
--- @param new_name string
function Recipe.replace_ingredient(recipe_name, old_name, new_name)
    local recipe = find_recipe(recipe_name)
    local kind = recipe and ingredient_type(new_name)
    if recipe and not kind then
        log('Ingredient not found: ' .. new_name)
    end
    if recipe and kind then
        for i, ingredient in pairs(recipe.ingredients or {}) do
            if ingredient.name == old_name then
                recipe.ingredients[i] = {type = kind, name = new_name, amount = ingredient.amount}
                return
            end
        end
    end
end

--- Have a technology unlock a recipe. The recipe starts disabled.
--- @param recipe_name string
--- @param technology_name string
function Recipe.add_unlock(recipe_name, technology_name)
    local recipe = find_recipe(recipe_name)
    local technology = data.raw.technology[technology_name]
    if recipe and not technology then
        log('Technology not found: ' .. technology_name)
    end
    if recipe and technology then
        recipe.enabled = false
        technology.effects = technology.effects or {}
        technology.effects[#technology.effects + 1] = {type = 'unlock-recipe', recipe = recipe_name}
    end
end

return Recipe
