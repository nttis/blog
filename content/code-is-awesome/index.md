+++
title = "Code is awesome"
date = 2025-03-17
+++

The more I program, the more I come to *greatly* appreciate the privilege
of being able to write code.

Code is *plaintext*, readable and comprehensible by humans. They can
easily be copy-pasted around, shared with the world, archived and saved.

They can be *version controlled*. Check source files into `git` and
upload them to a remote repository. With a few commands (or a few clicks
if you use a Git forge), you have the entire history of a project. You
can view all the changes made over time, by whom, to what, when,
at your fingertips.

Because of this, I have been trying to find ways to do as much in *code*
as possible. The more things that I can write in plaintext and check into
`git`, the better.

Here are a few things I have found solutions for.

# Word processing

Office programs are ubiquitous, but not for their convenience
or featureset or anything. They are ubiquitous only because they are
*necessary*.

I want to avoid having to open Microsoft Word or
[LibreOffice](https://www.libreoffice.org) as much as possible. `.docx`
(and other file formats) files are opaque, binary blobs. I can't just
open them up in a text editor and read their contents.

### Just use a `.md` file

[Markdown](https://en.wikipedia.org/wiki/Markdown) is simply godly. It's
plaintext that was *designed* from the start to look great both in
plaintext form and in processed form. It's extremely popular for good
reasons.

If you just want to quickly jot down something, just open a new `.md`
file and start writing.

### But the tables? Images?? Graphs???

Right, these are a tad bit too complex for Markdown. Markdown has support
for tables, but they aren't pleasant to write by hand. Graphs are also
only possible if you are a Great Wizard in the Art of ASCII.

This is why word processors were born: the need to present complex
documents. Academic papers, reports, resumés, infographics (no one does
infographics in Word though, right??), etc.

When I have absolutely no other choice (which is a situation I haven't
been in so far), I begrudgingly open LibreOffice and start typing up
a document.

However, in every other case, I write documents in code.

### TeX

[Donald Knuth](https://en.wikipedia.org/wiki/Donald_Knuth) gave the world
[TeX](https://en.wikipedia.org/wiki/TeX) almost 50 years ago. Since then,
it has been the best thing since sliced bread in academia.

TeX is *powerful*. It can do everything a word processor program
can do and more. The kicker? You write your documents in *code*, in
*plaintext*. A TeX engine then takes care of transforming that code into
a different form (pdf, docx, etc.), ready for consumption.

TeX source files are *plaintext*. If you open them up in Notepad, you
can immediately read them as-is and understand them. Of course, all
the formatting and layout options and whatnot will not be available,
but you can still read the *content*.

### Typst

[Typst](https://typst.app) is a modern TeX: proper, sane typesetting. And
I have to say, after using Typst a few times: it does it pretty well. It
is already capable enough to replace TeX, it's just a matter of waiting
for academia to *eventually* migrate away from TeX.

# Presentations, slides

Presentations are tough to tackle. They have to look pleasant, have to be
convenient and fast to make, have to look the same on every screen, have
to be shareable, have to be editable, have to be able to be collaborated
on by many people.

It's no wonder, then, that services like [Canva](https://canva.com) and
[Google Slides](https://doc.google.com/presentation) are so popular. After
all, they meet all the criteria.

The problem, though, is that the presentations you make aren't in
plaintext. And as far as I can tell, both of these services have no *real*
changes history.

For making slides, I use [reveal.js](https://revealjs.com). It's a
JavaScript library that allows you to write your slides in HTML and
present right in the web browser. It comes with a whole host of features
that you would expect from PowerPoint and other tools: presenter's view,
multiplexing, animations, transitions, multimedia, etc.

Let's look at the list:
- Slides have to look pleasant. Check.
- Slides have to be fast to make. Check.
- Slides have to look the same everywhere. Check.
- Has to be shareable. Check. It's just HTML.
- Has to be editable. Check. It's just HTML.
- Has to be collaborateable. Check. It's just code.

There are other solutions too, like [LaTeX
Beamer](https://latex-beamer.com/), but I am very happy with reveal.js
thus far.

# Aside: `pandoc`

[pandoc](https://pandoc.org) is a godly tool. It can convert to and from
many document/markup formats. If you find yourself needing to create
a simple `.docx`, try writing it in Markdown and convert it to `.docx`
with `pandoc` instead. The result is very good.

# Video editing

This is an extremely difficult problem to solve with code. Video editing
is inherently a *visual* task. Writing videos in code sounds borderline
impossible.

Still, there is [Motion Canvas](https://motioncanvas.io/). To quote the website
verbatim:

> A TypeScript library for creating animated videos using the Canvas API.

The author of Motion Canvas makes his own videos (which are quite complex,
mind you) in Motion Canvas itself! This proves that the tool is more
than enough for video editing and compositing.

An interesting consequence of doing this is that you can offload
video rendering to the cloud:tm: instead of doing it on your own
machine. [Google Colab](https://colab.research.google.com/) is a good
place to look.

# Audio and 3D modeling

Unfortunately, these are unsolved problems. There *are* some programmatic
CAD programs out there that allows you to model using code, but nothing
general-purpose like [Blender](https://blender.org).

Yes, I know that Blender has a scripting API, but I don't think it can
allow you to do the things I'm talking about.

The day a programmer can "write" a human model, a house model, a tree
model, a sword model, etc. in code is the day the world reaches utopia
status.
