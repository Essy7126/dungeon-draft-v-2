import { createContext, useContext } from 'react';
import type { Snapshot } from '../types';

const SnapshotContext = createContext<Snapshot | null>(null);

export const SnapshotProvider = SnapshotContext.Provider;

export function useSnapshot(): Snapshot {
  const snapshot = useContext(SnapshotContext);
  if (!snapshot) throw new Error('SnapshotProvider absent.');
  return snapshot;
}
