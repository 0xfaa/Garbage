import { type State } from "./state";
import { Registers, Stack } from "./stack";

export function parseAndExecute(stack: Stack, instruction: string): State {
    const parts = instruction.split(/\s+/);
    if (parts.length === 0) {
        console.log('instruction is empty');
        return stack.snapshot();
    }

    switch (parts[0]) {
        case 'strb':
        case 'ldrb': {
            const reg = parts[1].replace(',', '');
            let target = parts[2];
            if (parts.length === 4) {
                target += parts[3];
            }
            const memParts = target.replace(/[[\]]/g, '').split(',');
            const base = memParts[0] as keyof Registers;
            const offset = memParts.length > 1 ? parseInt(memParts[1].replace('#', ''), 10) : 0;
            
            if (parts[0] === 'strb') {
                stack.strb(reg, base, offset);
            } else {
                stack.ldrb(reg, base, offset);
            }
            break;
        }
        case 'add':
        case 'sub': {
            const dest = parts[1].replace(',', '') as keyof Registers;
            const src1 = parts[2].replace(',', '') as keyof Registers;
            let src2: keyof Registers | bigint;
            let immediate = false;

            if (parts[3].startsWith('#')) {
                src2 = BigInt(parts[3].replace('#', ''));
                immediate = true;
            } else {
                src2 = parts[3].replace(',', '') as keyof Registers;
            }

            if (parts[0] === 'add') {
                stack.add(dest, src1, src2, immediate);
            } else {
                stack.sub(dest, src1, src2, immediate);
            }
            break;
        }
        case 'stp': {
            const [reg1, reg2] = [parts[1].replace(',', ''), parts[2].replace(',', '')] as [keyof Registers, keyof Registers];
            let memPart = parts[3] + parts[4];
            const writeback = memPart.endsWith('!');
            if (writeback) {
                memPart = memPart.slice(0, -1);
            }
            const [base, offsetStr] = memPart.replace(/[[\]]/g, '').split(',');
            const offset = parseInt(offsetStr.replace('#', ''), 10);
            stack.stp(reg1, reg2, base as keyof Registers, offset, writeback);
            break;
        }
        case 'mov': {
            const dest = parts[1].replace(',', '') as keyof Registers;
            const src = parts[2];
            stack.mov(dest, src);
            break;
        }
        default:
            console.log(`Unknown instruction: ${parts[0]}`);
    }

    return stack.snapshot(instruction);
}