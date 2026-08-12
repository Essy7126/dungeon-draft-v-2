import type { Cell } from '../../content/schemas';
import type { GridState, UnitState } from '../model/types';

export function cellKey(cell: Cell): string {
  return `${cell.x},${cell.y}`;
}

export function sameCell(left: Cell, right: Cell): boolean {
  return left.x === right.x && left.y === right.y;
}

export function manhattan(left: Cell, right: Cell): number {
  return Math.abs(left.x - right.x) + Math.abs(left.y - right.y);
}

export function isInside(grid: GridState, cell: Cell): boolean {
  return cell.x >= 0 && cell.y >= 0 && cell.x < grid.width && cell.y < grid.height;
}

export function isBlocked(grid: GridState, cell: Cell): boolean {
  return grid.blockedCells.some((blocked) => sameCell(blocked, cell));
}

export function cardinalNeighbors(grid: GridState, cell: Cell): Cell[] {
  return [
    { x: cell.x, y: cell.y - 1 },
    { x: cell.x - 1, y: cell.y },
    { x: cell.x + 1, y: cell.y },
    { x: cell.x, y: cell.y + 1 },
  ].filter((candidate) => isInside(grid, candidate) && !isBlocked(grid, candidate))
    .sort(compareCells);
}

export function compareCells(left: Cell, right: Cell): number {
  return left.y - right.y || left.x - right.x;
}

export function occupiedKeys(units: readonly UnitState[], exceptUnitId: string | null = null): Set<string> {
  return new Set(units.filter((unit) => unit.alive && unit.id !== exceptUnitId).map((unit) => cellKey(unit.position)));
}

export function findPath(
  grid: GridState,
  start: Cell,
  goal: Cell,
  occupied: ReadonlySet<string>,
): Cell[] | null {
  if (!isInside(grid, goal) || isBlocked(grid, goal) || occupied.has(cellKey(goal))) return null;
  if (sameCell(start, goal)) return [];
  const queue: Cell[] = [start];
  const previous = new Map<string, Cell | null>([[cellKey(start), null]]);
  let cursor = 0;
  while (cursor < queue.length) {
    const current = queue[cursor];
    cursor += 1;
    if (current === undefined) break;
    for (const neighbor of cardinalNeighbors(grid, current)) {
      const key = cellKey(neighbor);
      if (previous.has(key) || occupied.has(key)) continue;
      previous.set(key, current);
      if (sameCell(neighbor, goal)) {
        const path: Cell[] = [neighbor];
        let back = current;
        while (!sameCell(back, start)) {
          path.push(back);
          const prior = previous.get(cellKey(back));
          if (prior === null || prior === undefined) break;
          back = prior;
        }
        return path.reverse();
      }
      queue.push(neighbor);
    }
  }
  return null;
}

export function reachableCells(grid: GridState, start: Cell, movement: number, occupied: ReadonlySet<string>): Cell[] {
  const found: Cell[] = [];
  const queue: Array<{ cell: Cell; distance: number }> = [{ cell: start, distance: 0 }];
  const visited = new Set<string>([cellKey(start)]);
  let cursor = 0;
  while (cursor < queue.length) {
    const entry = queue[cursor];
    cursor += 1;
    if (entry === undefined || entry.distance >= movement) continue;
    for (const neighbor of cardinalNeighbors(grid, entry.cell)) {
      const key = cellKey(neighbor);
      if (visited.has(key) || occupied.has(key)) continue;
      visited.add(key);
      found.push(neighbor);
      queue.push({ cell: neighbor, distance: entry.distance + 1 });
    }
  }
  return found.sort((left, right) => manhattan(start, left) - manhattan(start, right) || compareCells(left, right));
}

export function cardinalLine(start: Cell, end: Cell): Cell[] | null {
  if (start.x !== end.x && start.y !== end.y) return null;
  const dx = Math.sign(end.x - start.x);
  const dy = Math.sign(end.y - start.y);
  const length = manhattan(start, end);
  return Array.from({ length }, (_, index) => ({ x: start.x + dx * (index + 1), y: start.y + dy * (index + 1) }));
}

export function hasLineOfSight(grid: GridState, start: Cell, end: Cell, units: readonly UnitState[], targetUnitId: string): boolean {
  const line = cardinalLine(start, end);
  if (line === null) return false;
  for (const cell of line) {
    if (isBlocked(grid, cell)) return false;
    const occupant = units.find((unit) => unit.alive && sameCell(unit.position, cell));
    if (occupant !== undefined && occupant.id !== targetUnitId) return false;
  }
  return true;
}
