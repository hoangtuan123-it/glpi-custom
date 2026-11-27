<?php

/**
 * ---------------------------------------------------------------------
 *
 * GLPI - Gestionnaire Libre de Parc Informatique
 *
 * http://glpi-project.org
 *
 * @copyright 2015-2026 Teclib' and contributors.
 * @copyright 2003-2014 by the INDEPNET Development Team.
 * @licence   https://www.gnu.org/licenses/gpl-3.0.html
 *
 * ---------------------------------------------------------------------
 *
 * LICENSE
 *
 * This file is part of GLPI.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * ---------------------------------------------------------------------
 */

namespace Glpi\Cache;

use Psr\Cache\CacheItemPoolInterface;
use Psr\SimpleCache\CacheInterface;
use Symfony\Component\Cache\Psr16Cache;
use Throwable;

class SimpleCache extends Psr16Cache implements CacheInterface
{
    private ?Psr16Cache $fallback_cache = null;

    public function __construct(
        CacheItemPoolInterface $adapter,
        ?CacheItemPoolInterface $fallback_adapter = null
    ) {
        parent::__construct($adapter);
        if ($fallback_adapter !== null) {
            $this->fallback_cache = new Psr16Cache($fallback_adapter);
        }
    }

    public function get($key, $default = null): mixed
    {
        $normalized_key = $this->getNormalizedKey($key);
        try {
            return parent::get($normalized_key, $default);
        } catch (Throwable) {
            return $this->fallback_cache !== null
                ? $this->fallback_cache->get($normalized_key, $default)
                : $default;
        }
    }

    public function set($key, $value, $ttl = null): bool
    {
        $normalized_key = $this->getNormalizedKey($key);
        try {
            return parent::set($normalized_key, $value, $ttl);
        } catch (Throwable) {
            return $this->fallback_cache?->set($normalized_key, $value, $ttl) ?? false;
        }
    }

    public function delete($key): bool
    {
        $normalized_key = $this->getNormalizedKey($key);
        try {
            return parent::delete($normalized_key);
        } catch (Throwable) {
            return $this->fallback_cache?->delete($normalized_key) ?? false;
        }
    }

    public function getMultiple($keys, $default = null): iterable
    {
        $normalized_keys = array_map([$this, 'getNormalizedKey'], $keys);
        try {
            $result = parent::getMultiple($normalized_keys, $default);
        } catch (Throwable) {
            $result = $this->fallback_cache?->getMultiple($normalized_keys, $default) ?? [];
        }
        if (!is_array($result)) {
            $result = iterator_to_array($result);
        }

        $values_with_real_keys = [];
        foreach ($keys as $key) {
            $normalized_key = $this->getNormalizedKey($key);
            $values_with_real_keys[$key] = array_key_exists($normalized_key, $result)
                ? $result[$normalized_key]
                : $default;
        }

        return $values_with_real_keys;
    }

    public function setMultiple($values, $ttl = null): bool
    {
        $values_with_normalized_keys = [];
        foreach ($values as $key => $value) {
            $normalized_key = $this->getNormalizedKey($key);
            $values_with_normalized_keys[$normalized_key] = $value;
        }

        try {
            return parent::setMultiple($values_with_normalized_keys, $ttl);
        } catch (Throwable) {
            return $this->fallback_cache?->setMultiple($values_with_normalized_keys, $ttl) ?? false;
        }
    }

    public function deleteMultiple($keys): bool
    {
        $normalized_keys = array_map([$this, 'getNormalizedKey'], $keys);
        try {
            return parent::deleteMultiple($normalized_keys);
        } catch (Throwable) {
            return $this->fallback_cache?->deleteMultiple($normalized_keys) ?? false;
        }
    }

    public function has($key): bool
    {
        $normalized_key = $this->getNormalizedKey($key);
        try {
            return parent::has($normalized_key);
        } catch (Throwable) {
            return $this->fallback_cache?->has($normalized_key) ?? false;
        }
    }

    public function clear(): bool
    {
        $primary_success = true;
        try {
            $primary_success = parent::clear();
        } catch (Throwable) {
            $primary_success = false;
        }

        if ($this->fallback_cache !== null) {
            try {
                $fallback_success = $this->fallback_cache->clear();
            } catch (Throwable) {
                $fallback_success = false;
            }
            return $fallback_success && $primary_success;
        }

        return $primary_success;
    }

    /**
     * Returns normalized key to ensure compatibility with cache storage.
     *
     * @param string $key
     *
     * @return string
     */
    private function getNormalizedKey(string $key): string
    {
        return sha1($key);
    }
}
