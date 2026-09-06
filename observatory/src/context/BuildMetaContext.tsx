import { createContext, useContext } from 'react';
import { UNKNOWN_BUILD_META, type BuildMeta } from '../data/buildMeta';

const BuildMetaContext = createContext<BuildMeta>(UNKNOWN_BUILD_META);

export const BuildMetaProvider = BuildMetaContext.Provider;

export function useBuildMeta(): BuildMeta {
  return useContext(BuildMetaContext);
}
