---
name: llm-council
disable-model-invocation: true
description: "Run a decision or idea through a council of 5 sub-agent advisors with different thinking lenses, anonymous peer review, and a chairman verdict. Triggers: 'council this', 'run the council', 'war room this', 'pressure-test this', 'debate this'."
---

# LLM Council

For decisions with real uncertainty and a costly downside. Not for facts, creation tasks or summaries: just answer those.

## Advisors

1. **Contrarian**: assumes a fatal flaw and finds it.
2. **First Principles**: asks what we are actually solving, rebuilds from scratch, may say the question is wrong.
3. **Expansionist**: looks for the upside and adjacent opportunity nobody mentioned.
4. **Outsider**: no context on the user or field, reacts only to what is on the page, catches the curse of knowledge.
5. **Executor**: only cares about the fastest real path and the first step on Monday morning.

## Session

1. **Frame.** Read `CLAUDE.md`, memory and any file the user referenced (2-3 files, no more). Write one neutral prompt: the decision, the user's context, relevant numbers and constraints, what is at stake. No steering. If the question is too vague, ask one clarifying question.
2. **Convene.** Spawn the 5 advisors in parallel as sub-agents. Each gets its lens and the framed question, and must lean fully into its angle, no hedging, 150-300 words, no preamble.
3. **Peer review.** Anonymize the 5 answers as A-E in random order. Spawn 5 reviewers in parallel, each seeing all five, answering in under 200 words: strongest response, biggest blind spot, what all five missed.
4. **Chairman.** One agent gets the question, the de-anonymized answers and the reviews, and may side with a lone dissenter if its reasoning is strongest. Output, directly in chat, scannable bullets, no files:

   ```
   ## Council Verdict: {topic}
   ### Where the Council Agrees
   ### Where the Council Clashes
   ### Blind Spots the Council Caught
   ### The Recommendation   (a real answer, not "it depends")
   ### The One Thing to Do First   (a single step)
   ```

Save a transcript to `council-transcript-<timestamp>.md` only if the user asks.
