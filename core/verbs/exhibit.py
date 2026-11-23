from core.verbs.base import Result, Usage, Verb

async def exhibit(ctx, words):
    if words:
        raise Usage('exhibit takes no arguments')
    await ctx.core.exhibit.request()
    return Result('The Exhibit · The Fold', 'info', {})

VERBS = [Verb('exhibit', 'modes', 'exhibit', 'the machine performs itself', ('exhibit',), exhibit, record=False)]
