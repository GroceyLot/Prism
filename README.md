# Prism
### A fast language that compiles directly to lua with my dream syntax.
<sub>(Basically MoonScript but my dream syntax, and a bit worse)</sub>

## Features apart from lua:

### Keywords and symbols:

- `function` : `ritual`
- `return` : `reply`
- `not` : `~`
- `or` : `|`
- `and` : `&`

#### Keywords can be changed using this syntax:

```prism
@local=var@
```

This changes the local keyword to var for all you weirdos out there.

### Classes ✨:

Classes are defined with the class keyword like this:
```prism
class person(name, age)
{
	name = name,
	age = age
},
{
	tostring = ritual(self)
		reply "person(" .. self.name .. ", " .. self.age .. ")"
	end,
	is_adult = ritual(self)
		reply self.age >= 18
	end
} end
```

The first table is for properties and the second is for methods (and metamethods).

To construct one we can use this:
```prism
local mrbeast = person:new("Mr Beast", 123)
```

If we run this code:
```prism
print(mrbeast)
```
We will get this:
```output
person(Mr Beast, 123)
```

Classes can also extend others:
<sub>Notice how the local keyword is after class</sub>
```prism
class local employee(position) extends person
{
	position = position
},
{
	tostring = ritual(self)
		reply "employee(" .. self.name .. ", " .. self.age .. ", " .. self.position .. ")"
	end,
	promote = ritual(self, new_position)
		self.position = new_position
	end
} end
```

Classes have the methods and properties of the class it extends, unless they are overriden like tostring.

### Extras:

- Functions have local after the definition: `ritual local example() end`
- Define and call 0-argument functions with exclaimation marks: `ritual exclaim! print("Hello!") end`
- Strings are always multiline, and they use the following symbols: ``` ", ', ` ```
- Skip keyword! Works like luau continue, but is ignored when running in 5.1.
- Forget repeat until, they don't exist.
- Also you have the entire standard library of lua, or love2d (if you decide to use it).
