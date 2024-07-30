import { parseAndExecute, Stack, type State } from "./vizwiz";

const stack = new Stack(8)
stack.registers['x29'] = BigInt('0x1111111111111111')
stack.registers['x30'] = BigInt('0x2222222222222222')

const test: State[] = [stack.snapshot('init')]

test.push(parseAndExecute(stack, 'stp x29, x30, [sp, #-16]!'))
stack.decrement_label_renders()

test.push(parseAndExecute(stack, 'sub sp, sp, #48'))
stack.decrement_label_renders()

export const state: State[] = test