-- Copyright 2025 Specter Ops, Inc.
--
-- Licensed under the Apache License, Version 2.0
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- SPDX-License-Identifier: Apache-2.0

-- case: with '1' as target match (n:NodeKind1) where n.value = target return n
with s0 as (select '1' as i0),
     s1 as (select s0.i0 as i0, (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
            from s0,
                 node n0
            where n0.kind_ids operator (pg_catalog.&&) array [1]::int2[]
              and n0.properties ->> 'value' = s0.i0)
select s1.n0 as n
from s1;

-- case: match (n:NodeKind1) where n.value = 1 with n match (b) where id(b) = id(n) return b
with s0 as (with s1 as (select (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
                        from node n0
                        where (n0.properties ->> 'value')::int8 = 1
                          and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[])
            select s1.n0 as n0
            from s1),
     s2 as (select s0.n0 as n0, (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
            from s0,
                 node n1
            where n1.id = (s0.n0).id)
select s2.n1 as b
from s2;

-- case: match (n:NodeKind1) where n.value = 1 with n match (f) where f.name = 'me' with f match (b) where id(b) = id(f) return b
with s0 as (with s1 as (select (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
                        from node n0
                        where (n0.properties ->> 'value')::int8 = 1
                          and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[])
            select s1.n0 as n0
            from s1),
     s2 as (with s3 as (select s0.n0 as n0, (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
                        from node n1
                        where n1.properties ->> 'name' = 'me')
            select s3.n1 as n1
            from s3),
     s4 as (select s2.n1 as n1, (n2.id, n2.kind_ids, n2.properties)::nodecomposite as n2
            from s2,
                 node n2
            where n2.id = (s2.n1).id)
select s4.n2 as b
from s4;

-- case: match (n:NodeKind1)-[:EdgeKind1*1..]->(:NodeKind2)-[:EdgeKind2]->(m:NodeKind1) where (n:NodeKind1 or n:NodeKind2) and n.enabled = true with m, collect(distinct(n)) as p where size(p) >= 10 return m
with s0 as (with s1 as (with recursive s2(root_id, next_id, depth, satisfied, is_cycle, path) as (select e0.start_id,
                                                                                                         e0.end_id,
                                                                                                         1,
                                                                                                         n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                                         e0.start_id = e0.end_id,
                                                                                                         array [e0.id]
                                                                                                  from edge e0
                                                                                                         join node n0 on
                                                                                                    (n0.kind_ids operator (pg_catalog.&&)
                                                                                                     array [1]::int2[] or
                                                                                                     n0.kind_ids operator (pg_catalog.&&)
                                                                                                     array [2]::int2[]) and
                                                                                                    (n0.properties ->> 'enabled')::bool =
                                                                                                    true and
                                                                                                    n0.kind_ids operator (pg_catalog.&&)
                                                                                                    array [1]::int2[] and
                                                                                                    n0.id = e0.start_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where e0.kind_id = any (array [3]::int2[])
                                                                                                  union
                                                                                                  select s2.root_id,
                                                                                                         e0.end_id,
                                                                                                         s2.depth + 1,
                                                                                                         n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                                         e0.id = any (s2.path),
                                                                                                         s2.path || e0.id
                                                                                                  from s2
                                                                                                         join edge e0 on e0.start_id = s2.next_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where s2.depth < 10
                                                                                                    and not s2.is_cycle
                                                                                                    and e0.kind_id = any (array [3]::int2[]))
                        select (select array_agg((e0.id, e0.start_id, e0.end_id, e0.kind_id, e0.properties)::edgecomposite)
                                from edge e0
                                where e0.id = any (s2.path))                      as e0,
                               s2.path                                            as ep0,
                               (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0,
                               (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
                        from s2
                               join edge e0 on e0.id = any (s2.path)
                               join node n0 on n0.id = s2.root_id
                               join node n1 on e0.id = s2.path[array_length(s2.path, 1)::int] and n1.id = e0.end_id
                        where s2.satisfied),
                 s3 as (select s1.e0                                                                     as e0,
                               (e1.id, e1.start_id, e1.end_id, e1.kind_id, e1.properties)::edgecomposite as e1,
                               s1.ep0                                                                    as ep0,
                               s1.n0                                                                     as n0,
                               s1.n1                                                                     as n1,
                               (n2.id, n2.kind_ids, n2.properties)::nodecomposite                        as n2
                        from s1,
                             edge e1
                               join node n2
                                    on n2.kind_ids operator (pg_catalog.&&) array [1]::int2[] and n2.id = e1.end_id
                        where e1.kind_id = any (array [4]::int2[])
                          and (s1.e0[array_length(s1.e0, 1)::int]).end_id = e1.start_id)
            select s3.n2 as n2, array_agg(distinct (n0))::nodecomposite[] as i0
            from s3
            group by n2)
select s0.n2 as m
from s0
where array_length(s0.i0, 1)::int >= 10;

-- case: match (n:NodeKind1)-[:EdgeKind1*1..]->(:NodeKind2)-[:EdgeKind2]->(m:NodeKind1) where (n:NodeKind1 or n:NodeKind2) and n.enabled = true with m, count(distinct(n)) as p where p >= 10 return m
with s0 as (with s1 as (with recursive s2(root_id, next_id, depth, satisfied, is_cycle, path) as (select e0.start_id,
                                                                                                         e0.end_id,
                                                                                                         1,
                                                                                                         n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                                         e0.start_id = e0.end_id,
                                                                                                         array [e0.id]
                                                                                                  from edge e0
                                                                                                         join node n0 on
                                                                                                    (n0.kind_ids operator (pg_catalog.&&)
                                                                                                     array [1]::int2[] or
                                                                                                     n0.kind_ids operator (pg_catalog.&&)
                                                                                                     array [2]::int2[]) and
                                                                                                    (n0.properties ->> 'enabled')::bool =
                                                                                                    true and
                                                                                                    n0.kind_ids operator (pg_catalog.&&)
                                                                                                    array [1]::int2[] and
                                                                                                    n0.id = e0.start_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where e0.kind_id = any (array [3]::int2[])
                                                                                                  union
                                                                                                  select s2.root_id,
                                                                                                         e0.end_id,
                                                                                                         s2.depth + 1,
                                                                                                         n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                                         e0.id = any (s2.path),
                                                                                                         s2.path || e0.id
                                                                                                  from s2
                                                                                                         join edge e0 on e0.start_id = s2.next_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where s2.depth < 10
                                                                                                    and not s2.is_cycle
                                                                                                    and e0.kind_id = any (array [3]::int2[]))
                        select (select array_agg((e0.id, e0.start_id, e0.end_id, e0.kind_id, e0.properties)::edgecomposite)
                                from edge e0
                                where e0.id = any (s2.path))                      as e0,
                               s2.path                                            as ep0,
                               (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0,
                               (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
                        from s2
                               join edge e0 on e0.id = any (s2.path)
                               join node n0 on n0.id = s2.root_id
                               join node n1 on e0.id = s2.path[array_length(s2.path, 1)::int] and n1.id = e0.end_id
                        where s2.satisfied),
                 s3 as (select s1.e0                                                                     as e0,
                               (e1.id, e1.start_id, e1.end_id, e1.kind_id, e1.properties)::edgecomposite as e1,
                               s1.ep0                                                                    as ep0,
                               s1.n0                                                                     as n0,
                               s1.n1                                                                     as n1,
                               (n2.id, n2.kind_ids, n2.properties)::nodecomposite                        as n2
                        from s1,
                             edge e1
                               join node n2
                                    on n2.kind_ids operator (pg_catalog.&&) array [1]::int2[] and n2.id = e1.end_id
                        where e1.kind_id = any (array [4]::int2[])
                          and (s1.e0[array_length(s1.e0, 1)::int]).end_id = e1.start_id)
            select s3.n2 as n2, count((n0))::int8 as i0
            from s3
            group by n2)
select s0.n2 as m
from s0
where s0.i0 >= 10;

-- case: with 365 as max_days match (n:NodeKind1) where n.pwdlastset < (datetime().epochseconds - (max_days * 86400)) and not n.pwdlastset IN [-1.0, 0.0] return n limit 100
with s0 as (select 365 as i0),
     s1 as (select s0.i0 as i0, (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
            from s0,
                 node n0
            where not (n0.properties ->> 'pwdlastset')::float8 = any (array [- 1, 0]::float8[])
              and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[]
              and (n0.properties ->> 'pwdlastset')::numeric <
                  (extract(epoch from now()::timestamp with time zone)::numeric - (s0.i0 * 86400)))
select s1.n0 as n
from s1
limit 100;

-- case: match (n:NodeKind1) where n.hasspn = true and n.enabled = true and not n.objectid ends with '-502' and not coalesce(n.gmsa, false) = true and not coalesce(n.msa, false) = true match (n)-[:EdgeKind1|EdgeKind2*1..]->(c:NodeKind2) with distinct n, count(c) as adminCount return n order by adminCount desc limit 100
with s0 as (with s1 as (select (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
                        from node n0
                        where (n0.properties ->> 'hasspn')::bool = true
                          and (n0.properties ->> 'enabled')::bool = true
                          and not coalesce(n0.properties ->> 'objectid', '')::text like '%-502'
                          and not coalesce((n0.properties ->> 'gmsa')::bool, false)::bool = true
                          and not coalesce((n0.properties ->> 'msa')::bool, false)::bool = true
                          and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[]),
                 s2 as (with recursive s3(root_id, next_id, depth, satisfied, is_cycle, path) as (select e0.start_id,
                                                                                                         e0.end_id,
                                                                                                         1,
                                                                                                         n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                                         e0.start_id = e0.end_id,
                                                                                                         array [e0.id]
                                                                                                  from s1
                                                                                                         join edge e0 on e0.start_id = (s1.n0).id
                                                                                                         join node n0 on (s1.n0).id = e0.start_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where e0.kind_id = any (array [3, 4]::int2[])
                                                                                                  union
                                                                                                  select s3.root_id,
                                                                                                         e0.end_id,
                                                                                                         s3.depth + 1,
                                                                                                         n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                                         e0.id = any (s3.path),
                                                                                                         s3.path || e0.id
                                                                                                  from s3
                                                                                                         join edge e0 on e0.start_id = s3.next_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where s3.depth < 10
                                                                                                    and not s3.is_cycle
                                                                                                    and e0.kind_id = any (array [3, 4]::int2[]))
                        select (select array_agg((e0.id, e0.start_id, e0.end_id, e0.kind_id, e0.properties)::edgecomposite)
                                from edge e0
                                where e0.id = any (s3.path))                      as e0,
                               s3.path                                            as ep0,
                               s1.n0                                              as n0,
                               (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
                        from s1,
                             s3
                               join edge e0 on e0.id = any (s3.path)
                               join node n0 on n0.id = s3.root_id
                               join node n1 on e0.id = s3.path[array_length(s3.path, 1)::int] and n1.id = e0.end_id
                        where s3.satisfied)
            select s2.n0 as n0, count(s2.n1)::int8 as i0
            from s2
            group by n0)
select s0.n0 as n
from s0
order by i0 desc
limit 100;

-- case: match (n:NodeKind1) where n.objectid = 'S-1-5-21-1260426776-3623580948-1897206385-23225' match p = (n)-[:EdgeKind1|EdgeKind2*1..]->(c:NodeKind2) return p
with s0 as (select (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
            from node n0
            where n0.properties ->> 'objectid' = 'S-1-5-21-1260426776-3623580948-1897206385-23225'
              and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[]),
     s1 as (with recursive s2(root_id, next_id, depth, satisfied, is_cycle, path) as (select e0.start_id,
                                                                                             e0.end_id,
                                                                                             1,
                                                                                             n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                             e0.start_id = e0.end_id,
                                                                                             array [e0.id]
                                                                                      from s0
                                                                                             join edge e0 on e0.start_id = (s0.n0).id
                                                                                             join node n0 on (s0.n0).id = e0.start_id
                                                                                             join node n1 on n1.id = e0.end_id
                                                                                      where e0.kind_id = any (array [3, 4]::int2[])
                                                                                      union
                                                                                      select s2.root_id,
                                                                                             e0.end_id,
                                                                                             s2.depth + 1,
                                                                                             n1.kind_ids operator (pg_catalog.&&) array [2]::int2[],
                                                                                             e0.id = any (s2.path),
                                                                                             s2.path || e0.id
                                                                                      from s2
                                                                                             join edge e0 on e0.start_id = s2.next_id
                                                                                             join node n1 on n1.id = e0.end_id
                                                                                      where s2.depth < 10
                                                                                        and not s2.is_cycle
                                                                                        and e0.kind_id = any (array [3, 4]::int2[]))
            select (select array_agg((e0.id, e0.start_id, e0.end_id, e0.kind_id, e0.properties)::edgecomposite)
                    from edge e0
                    where e0.id = any (s2.path))                      as e0,
                   s2.path                                            as ep0,
                   s0.n0                                              as n0,
                   (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
            from s0,
                 s2
                   join edge e0 on e0.id = any (s2.path)
                   join node n0 on n0.id = s2.root_id
                   join node n1 on e0.id = s2.path[array_length(s2.path, 1)::int] and n1.id = e0.end_id
            where s2.satisfied)
select edges_to_path(variadic ep0)::pathcomposite as p
from s1;

-- case: match (g1:NodeKind1) where g1.name starts with 'test' with collect (g1.domain) as excludes match (d:NodeKind2) where d.name starts with 'other' and not d.name in excludes return d
with s0 as (with s1 as (select (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
                        from node n0
                        where n0.properties ->> 'name' like 'test%'
                          and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[])
            select array_agg((s1.n0).properties ->> 'domain')::anyarray as i0
            from s1),
     s2 as (select s0.i0 as i0, (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
            from s0,
                 node n1
            where n1.properties ->> 'name' like 'other%'
              and n1.kind_ids operator (pg_catalog.&&) array [2]::int2[]
              and not n1.properties ->> 'name' = any (i0))
select s2.n1 as d
from s2;

-- case: with 'a' as uname match (o:NodeKind1) where o.name starts with uname and o.domain = ' ' return o
with s0 as (select 'a' as i0),
     s1 as (select s0.i0 as i0, (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0
            from s0,
                 node n0
            where n0.properties ->> 'domain' = ' '
              and n0.kind_ids operator (pg_catalog.&&) array [1]::int2[]
              and n0.properties ->> 'name' like s0.i0 || '%')
select s1.n0 as o
from s1;

-- case: match (dc)-[r:EdgeKind1*0..]->(g:NodeKind1) where g.objectid ends with '-516' with collect(dc) as exclude match p = (c:NodeKind2)-[n:EdgeKind2]->(u:NodeKind2)-[:EdgeKind2*1..]->(g:NodeKind1) where g.objectid ends with '-512' and not c in exclude return p limit 100
with s0 as (with s1 as (with recursive s2(root_id, next_id, depth, satisfied, is_cycle, path) as (select e0.start_id,
                                                                                                         e0.end_id,
                                                                                                         1,
                                                                                                         n1.properties ->>
                                                                                                         'objectid' like
                                                                                                         '%-516' and
                                                                                                         n1.kind_ids operator (pg_catalog.&&)
                                                                                                         array [1]::int2[],
                                                                                                         e0.start_id = e0.end_id,
                                                                                                         array [e0.id]
                                                                                                  from edge e0
                                                                                                         join node n0 on n0.id = e0.start_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where e0.kind_id = any (array [3]::int2[])
                                                                                                  union
                                                                                                  select s2.root_id,
                                                                                                         e0.end_id,
                                                                                                         s2.depth + 1,
                                                                                                         n1.properties ->>
                                                                                                         'objectid' like
                                                                                                         '%-516' and
                                                                                                         n1.kind_ids operator (pg_catalog.&&)
                                                                                                         array [1]::int2[],
                                                                                                         e0.id = any (s2.path),
                                                                                                         s2.path || e0.id
                                                                                                  from s2
                                                                                                         join edge e0 on e0.start_id = s2.next_id
                                                                                                         join node n1 on n1.id = e0.end_id
                                                                                                  where s2.depth < 10
                                                                                                    and not s2.is_cycle
                                                                                                    and e0.kind_id = any (array [3]::int2[]))
                        select (select array_agg((e0.id, e0.start_id, e0.end_id, e0.kind_id, e0.properties)::edgecomposite)
                                from edge e0
                                where e0.id = any (s2.path))                      as e0,
                               s2.path                                            as ep0,
                               (n0.id, n0.kind_ids, n0.properties)::nodecomposite as n0,
                               (n1.id, n1.kind_ids, n1.properties)::nodecomposite as n1
                        from s2
                               join edge e0 on e0.id = any (s2.path)
                               join node n0 on n0.id = s2.root_id
                               join node n1 on e0.id = s2.path[array_length(s2.path, 1)::int] and n1.id = e0.end_id
                        where s2.satisfied)
            select array_agg(s1.n0)::nodecomposite[] as i0
            from s1),
     s3 as (select (e1.id, e1.start_id, e1.end_id, e1.kind_id, e1.properties)::edgecomposite as e1,
                   s0.i0                                                                     as i0,
                   (n2.id, n2.kind_ids, n2.properties)::nodecomposite                        as n2,
                   (n3.id, n3.kind_ids, n3.properties)::nodecomposite                        as n3
            from s0,
                 edge e1
                   join node n2 on n2.kind_ids operator (pg_catalog.&&) array [2]::int2[] and n2.id = e1.start_id
                   join node n3 on n3.kind_ids operator (pg_catalog.&&) array [2]::int2[] and n3.id = e1.end_id
            where e1.kind_id = any (array [4]::int2[])
              and not n2.id = any (i0.id)),
     s4 as (with recursive s5(root_id, next_id, depth, satisfied, is_cycle, path) as (select e2.start_id,
                                                                                             e2.end_id,
                                                                                             1,
                                                                                             false,
                                                                                             e2.start_id = e2.end_id,
                                                                                             array [e2.id]
                                                                                      from s3
                                                                                             join edge e2
                                                                                                  on e2.kind_id = any (array [4]::int2[]) and (s3.n3).id = e2.start_id
                                                                                             join node n4 on n4.id = e2.end_id
                                                                                      union
                                                                                      select s5.root_id,
                                                                                             e2.end_id,
                                                                                             s5.depth + 1,
                                                                                             n4.properties ->>
                                                                                             'objectid' like '%-512' and
                                                                                             n4.kind_ids operator (pg_catalog.&&)
                                                                                             array [1]::int2[],
                                                                                             e2.id = any (s5.path),
                                                                                             s5.path || e2.id
                                                                                      from s5
                                                                                             join edge e2 on e2.start_id = s5.next_id
                                                                                             join node n4 on n4.id = e2.end_id
                                                                                      where s5.depth < 10
                                                                                        and not s5.is_cycle)
            select s3.e1                                              as e1,
                   (select array_agg((e2.id, e2.start_id, e2.end_id, e2.kind_id, e2.properties)::edgecomposite)
                    from edge e2
                    where e2.id = any (s5.path))                      as e2,
                   s5.path                                            as ep1,
                   s3.i0                                              as i0,
                   s3.n2                                              as n2,
                   s3.n3                                              as n3,
                   (n4.id, n4.kind_ids, n4.properties)::nodecomposite as n4
            from s3,
                 s5
                   join edge e2 on e2.id = any (s5.path)
                   join node n3 on n3.id = s5.root_id
                   join node n4 on e2.id = s5.path[array_length(s5.path, 1)::int] and n4.id = e2.end_id)
select edges_to_path(variadic array [(s4.e1).id]::int8[] || s4.ep1)::pathcomposite as p
from s4
limit 100;
