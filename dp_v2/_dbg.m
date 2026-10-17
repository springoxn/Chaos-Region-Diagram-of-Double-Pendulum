addpath('core'); addpath('maps'); addpath('analysis'); addpath('tests');
try
  R = sp_compare_forced('N',6,'periods',20,'periodsInd',20,'cases',{{1.5 0.2}});
catch ME
  fprintf('ERR: %s\n', ME.message);
  for k=1:numel(ME.stack)
    fprintf('  at %s line %d\n', ME.stack(k).name, ME.stack(k).line);
  end
end
