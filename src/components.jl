##################################################
# Component types
abstract type UCComponentType end
abstract type RequiredConstraints <: UCComponentType end
abstract type SystemConstraints <: UCComponentType end
abstract type GenerationLimits <: UCComponentType end
abstract type PiecewiseProduction <: UCComponentType end
abstract type UpDownTime <: UCComponentType end
abstract type ReserveConstraints <: UCComponentType end
abstract type RampLimits <: UCComponentType end
abstract type StartupCosts <: UCComponentType end
abstract type ShutdownCosts <: UCComponentType end

##################################################
# Components
"""
Generic component of the unit commitment problem.

Elements
===
 * `name`: name of the component
 * `description`: gives a brief summary of what the component adds
 * `type`: reference back to the UCComponentType being modeled
 * `vars`: required variables
 * `constrs`: constraints that are created by this function
 * `add_component`: function to add constraints and update the objective to capture this component
 * `params`: extra parameters the component might use
"""
mutable struct UCComponent
  "Name of the component."
  name::String
  "Description of what the component adds."
  description::String
  "Which part of the unit commitment problem is modeled by this component."
  type::Type{<:UCComponentType}
  "Variables that are needed for the component (subset of `var_list`)."
  vars::Union{Array{Symbol},Nothing}
  "Equations that are modified for the component (subset of `constr_list`)."
  constrs::Union{Array{Symbol},Nothing}
  "Function to add constraints and objective coefficients needed for this component to the model. Signature should be (component, mip, model)."
  add_component::Union{Function,Nothing}
  "Extra parameters for the component."
  params::Any
end # struct UCComponent

export UCComponent
