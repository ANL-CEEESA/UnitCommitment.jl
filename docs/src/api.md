# API Reference

## Read data, build model & optimize

```@docs
UnitCommitment.read
UnitCommitment.read_benchmark
UnitCommitment.build_model
UnitCommitment.optimize!
UnitCommitment.solution
UnitCommitment.validate
UnitCommitment.write
```

## Modify instance

```@docs
UnitCommitment.slice
UnitCommitment.randomize!(::UnitCommitment.UnitCommitmentInstance)
UnitCommitment.generate_initial_conditions!
```

## Formulations

```@docs
UnitCommitment.Formulation
UnitCommitment.ShiftFactorsFormulation
UnitCommitment.ArrCon2000
UnitCommitment.CarArr2006
UnitCommitment.DamKucRajAta2016
UnitCommitment.Gar1962
UnitCommitment.KnuOstWat2018
UnitCommitment.MorLatRam2013
UnitCommitment.PanGua2016
UnitCommitment.WanHob2016
```

## Solution Methods

```@docs
UnitCommitment.XavQiuWanThi2019.Method
```

## Randomization Methods

```@docs
UnitCommitment.XavQiuAhm2021.Randomization
```
