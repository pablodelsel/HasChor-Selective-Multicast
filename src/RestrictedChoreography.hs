{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module RestrictedChoreography
  ( RestrictedChoreo
  , Member
  , locallyR
  , commR
  , condR
  , condSelective
  , KnownRoles
  ) where

import Choreography.Choreo (Choreo, Unwrap, locally, (~>), cond, ChoreoSig(..))
import Choreography.Location (type (@), LocTm)
import Control.Monad.Freer (toFreer)

import Data.List (nub)
import Data.Kind (Constraint)
import Data.Proxy (Proxy(..))
import GHC.TypeLits ( Symbol, KnownSymbol, symbolVal, TypeError, ErrorMessage(..))


-- Type class `KnownRoles` provides runtime access to the locations represented by a type-level census.
-- `rolesVal` recovers the location identifiers from a type-level list of Proxies.
class KnownRoles (rs :: [Symbol]) where
  rolesVal :: Proxy rs -> [LocTm]

instance KnownRoles '[] where
  rolesVal _  =  []

instance (KnownSymbol r, KnownRoles rs) => KnownRoles (r ': rs) where
  rolesVal _  =  symbolVal (Proxy @r) : rolesVal (Proxy @rs)


-- Checks whether a location belongs to a list of locations.
type family Member (r :: Symbol) (rs :: [Symbol]) :: Constraint where
  Member r '[]  =  TypeError ('Text "The location " ':<>: 'ShowType r ':<>: 'Text " is not included in the restricted census")
  Member r (r ': rs) = ()
  Member r (x ': rs) = Member r rs


-- Represents a choreography restricted to a set of locations.
newtype RestrictedChoreo (rs :: [Symbol]) m a  =  RestrictedChoreo (Choreo m a)
  deriving newtype (Functor, Applicative, Monad)

-- Prevents the participant list from being modified using coerce.
type role RestrictedChoreo nominal _ _


-- Internal function; not exported.
unRestricted :: RestrictedChoreo rs m a -> Choreo m a
unRestricted (RestrictedChoreo c)  =  c


-- Local computation restricted to locations in the census.
locallyR :: (KnownSymbol r, Member r rs)
         => Proxy r
         -> (Unwrap r -> m a)
         -> RestrictedChoreo rs m (a @ r)
locallyR role action  =  RestrictedChoreo (locally role action)


-- Communication restricted to locations in the census.
commR :: ( Show a, Read a, KnownSymbol r, KnownSymbol r', Member r rs, Member r' rs)
      => (Proxy r, a @ r)
      -> Proxy r'
      -> RestrictedChoreo rs m (a @ r')
commR message destination  =  RestrictedChoreo (message ~> destination)


-- | Auxiliary internal function to build all conditional effects
-- It needs no `Member` restrictions as those have been validated in the public API functions
selectiveEffect :: (Show a, Read a, KnownSymbol r)
                => [LocTm]
                -> (Proxy r, a @ r)
                -> (a -> RestrictedChoreo rs m ())
                -> Choreo m ()
selectiveEffect roles (role, value) body  =  toFreer $ CondSelective roles role value (unRestricted . body)


-- | Conditional restricted to the locations in the census of the `RestrictedChoreo`
condR :: forall rs r a m. (Show a, Read a, KnownSymbol r, Member r rs, KnownRoles rs)
      => (Proxy r, a @ r)
      -> (a -> RestrictedChoreo rs m ())
      -> RestrictedChoreo rs m ()
condR decision body  =  RestrictedChoreo $ selectiveEffect (nub (rolesVal (Proxy @rs))) decision body

-- | A variant of `cond` that optimizes messages traffic by using selective multicast
-- targeting only the locations declared (and referenced) in the operation.
-- `KnownRoles` class provides `rolesVal` to obtain location identifiers from the type-level census.
-- nub avoids targeting duplicate locations.
condSelective :: (Show a, Read a, KnownSymbol r, Member r rs, KnownRoles rs)
              => Proxy rs
              -> (Proxy r, a @ r)
              -> (a -> RestrictedChoreo rs m ())
              -> Choreo m ()
condSelective roles decision body  =  selectiveEffect (nub (rolesVal roles)) decision body
