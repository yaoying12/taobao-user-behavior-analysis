-- =============================================================================
-- 淘宝用户行为分析 — MySQL Workbench SQL文件
-- =============================================================================
-- 数据库：taobao_analysis | 表：user_behavior
-- 数据范围：2017-11-25 ~ 2017-12-03（仅9天有效数据）
-- 过滤条件：WHERE timestamp BETWEEN 1511539200 AND 1512316799
-- 脏数据已清理：
--   原表 100,150,807 条
--   删除 timestamp < 1511539200 或 > 1512316799 的记录后，剩余 100,095,231 条
-- FROM_UNIXTIME() 已在脏数据清除后正常工作
-- 执行顺序：从上到下依次执行
-- =============================================================================

-- ==============================================================
-- 通用过滤条件（所有查询都需要加 WHERE 子句）
-- ==============================================================
-- WHERE timestamp BETWEEN 1511539200 AND 1512316799
-- 1511539200 = 2017-11-25 00:00:00
-- 1512316799 = 2017-12-03 23:59:59
-- 说明：11月24日仅4万条(非爆发期)，12月4日后每天仅几百条，均已删除


-- ==============================================================
-- 目标1：数据预览（看前10条、数据时间范围、基本统计量）
-- ==============================================================

-- ① 看前10条原始数据
SELECT * FROM user_behavior LIMIT 10;

-- ② 数据时间范围和基本信息
-- 说明：脏数据清除后，FROM_UNIXTIME() 正常工作
SELECT 
    MIN(FROM_UNIXTIME(timestamp)) AS 最早时间,
    MAX(FROM_UNIXTIME(timestamp)) AS 最晚时间,
    COUNT(DISTINCT DATE(FROM_UNIXTIME(timestamp))) AS 总天数,
    COUNT(*) AS 总记录数,
    COUNT(DISTINCT user_id) AS 独立用户数,
    COUNT(DISTINCT item_id) AS 独立商品数,
    COUNT(DISTINCT category_id) AS 独立品类数
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799;

-- ③ 验证：每天的记录数（应只有9天，每天约1000万条）
SELECT 
    DATE(FROM_UNIXTIME(timestamp)) AS dt,
    COUNT(*) AS cnt
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY dt
ORDER BY dt;


-- ==============================================================
-- 目标2：整体大盘指标（总PV、总UV、总行为数、购买总人数）
-- ==============================================================

-- ②-1 总量统计
SELECT 
    COUNT(*) AS 总记录数,
    COUNT(DISTINCT user_id) AS 总UV,
    SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS 总PV,
    SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS 总收藏,
    SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS 总加购,
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS 购买次数,
    COUNT(DISTINCT CASE WHEN behavior_type = 'buy' THEN user_id END) AS 购买人数
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799;

-- ②-2 各行为占比
SELECT 
    behavior_type,
    COUNT(*) AS 次数,
    ROUND(COUNT(*) * 100.0 / 
        (SELECT COUNT(*) FROM user_behavior 
         WHERE timestamp BETWEEN 1511539200 AND 1512316799), 2) AS 占比百分比
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY behavior_type
ORDER BY 次数 DESC;


-- ==============================================================
-- 目标3：行为漏斗（pv / fav / cart / buy 各多少，两两转化率）
-- ==============================================================

-- ③-1 各行为数量
SELECT 
    SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS 浏览,
    SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS 收藏,
    SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS 加购,
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS 购买
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799;

-- ③-2 两两转化率
WITH funnel AS (
    SELECT 
        SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS 浏览,
        SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS 收藏,
        SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS 加购,
        SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS 购买
    FROM user_behavior
    WHERE timestamp BETWEEN 1511539200 AND 1512316799
)
SELECT 
    浏览, 收藏, 加购, 购买,
    ROUND(收藏 * 100.0 / 浏览, 2) AS 浏览_收藏转化率,
    ROUND(加购 * 100.0 / 收藏, 2) AS 收藏_加购转化率,
    ROUND(购买 * 100.0 / 加购, 2) AS 加购_购买转化率,
    ROUND(购买 * 100.0 / 浏览, 2) AS 浏览_购买转化率
FROM funnel;


-- ==============================================================
-- 目标4：每日趋势（每天的PV、UV、购买量）
-- ==============================================================

SELECT 
    DATE(FROM_UNIXTIME(timestamp)) AS 日期,
    SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS PV,
    COUNT(DISTINCT user_id) AS UV,
    SUM(CASE WHEN behavior_type = 'fav' THEN 1 ELSE 0 END) AS 收藏数,
    SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS 加购数,
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS 购买量
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY DATE(FROM_UNIXTIME(timestamp))
ORDER BY 日期;


-- ==============================================================
-- 目标5：小时分布（一天24小时每小时的行为量）
-- ==============================================================

SELECT 
    HOUR(FROM_UNIXTIME(timestamp)) AS 小时,
    COUNT(*) AS 行为量,
    COUNT(DISTINCT user_id) AS 独立用户数
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY HOUR(FROM_UNIXTIME(timestamp))
ORDER BY 小时;


-- ==============================================================
-- 目标6：热门商品（被浏览/加购/购买最多的TOP10商品）
-- ==============================================================

-- ⑥-1 按购买量排名 TOP10
SELECT item_id, COUNT(*) AS 购买次数
FROM user_behavior
WHERE behavior_type = 'buy'
  AND timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY item_id
ORDER BY 购买次数 DESC
LIMIT 10;

-- ⑥-2 按浏览量排名 TOP10
SELECT item_id, COUNT(*) AS 浏览次数
FROM user_behavior
WHERE behavior_type = 'pv'
  AND timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY item_id
ORDER BY 浏览次数 DESC
LIMIT 10;

-- ⑥-3 按加购量排名 TOP10
SELECT item_id, COUNT(*) AS 加购次数
FROM user_behavior
WHERE behavior_type = 'cart'
  AND timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY item_id
ORDER BY 加购次数 DESC
LIMIT 10;

-- ⑥-4 综合热度排名（浏览+加购+购买）
SELECT 
    item_id,
    SUM(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS 浏览量,
    SUM(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS 加购量,
    SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS 购买量,
    COUNT(*) AS 总热度
FROM user_behavior
WHERE timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY item_id
ORDER BY 总热度 DESC
LIMIT 10;


-- ==============================================================
-- 目标7：热门品类（被购买最多的TOP10品类）
-- ==============================================================

SELECT 
    category_id, 
    COUNT(*) AS 购买次数
FROM user_behavior
WHERE behavior_type = 'buy'
  AND timestamp BETWEEN 1511539200 AND 1512316799
GROUP BY category_id
ORDER BY 购买次数 DESC
LIMIT 10;


-- ==============================================================
-- 目标8：复购分析（买1次、2次、3次的用户各有多少，复购率）
-- ==============================================================

-- ⑧-1 每个购买用户的购买次数分布
WITH user_buy AS (
    SELECT user_id, COUNT(*) AS buy_times
    FROM user_behavior
    WHERE behavior_type = 'buy'
      AND timestamp BETWEEN 1511539200 AND 1512316799
    GROUP BY user_id
)
SELECT 
    buy_times,
    COUNT(*) AS 用户数,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM user_buy), 2) AS 占比百分比
FROM user_buy
GROUP BY buy_times
ORDER BY buy_times;

-- ⑧-2 复购率（购买≥2次的用户占比）
WITH user_buy AS (
    SELECT user_id, COUNT(*) AS buy_times
    FROM user_behavior
    WHERE behavior_type = 'buy'
      AND timestamp BETWEEN 1511539200 AND 1512316799
    GROUP BY user_id
)
SELECT 
    COUNT(*) AS 总购买用户数,
    SUM(CASE WHEN buy_times >= 2 THEN 1 ELSE 0 END) AS 复购用户数,
    ROUND(100.0 * SUM(CASE WHEN buy_times >= 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS 复购率
FROM user_buy;


-- ==============================================================
-- 目标9：RFM分析（R×F 二维四象限）
-- ==============================================================

-- ⚠️ 说明：本分析仅覆盖购买用户（672,404人），未购用户315,587人不参与RFM分析
-- ❌ 取消M(Monetary)：原始数据无金额字段，M与F完全相同导致8档分层实际只有4档
-- ✅ 改为R×F二维四象限

-- ⑨-1 每个用户的R、F值
-- R = 距基准日(2017-12-03)的天数（越小=刚买=价值高）
-- F = 购买次数（越大=价值高）
WITH user_rfm AS (
    SELECT 
        user_id,
        DATEDIFF('2017-12-03', DATE(FROM_UNIXTIME(MAX(timestamp)))) AS R,
        COUNT(*) AS F
    FROM user_behavior
    WHERE behavior_type = 'buy'
      AND timestamp BETWEEN 1511539200 AND 1512316799
    GROUP BY user_id
)
SELECT * FROM user_rfm ORDER BY R ASC;

-- ⑨-2 四象限分层统计
-- 只有4个分层会出现：高-高 / 高-低 / 低-高 / 低-低
WITH user_rfm AS (
    SELECT 
        user_id,
        DATEDIFF('2017-12-03', DATE(FROM_UNIXTIME(MAX(timestamp)))) AS R,
        COUNT(*) AS F,
        CASE 
            WHEN DATEDIFF('2017-12-03', DATE(FROM_UNIXTIME(MAX(timestamp)))) < (SELECT AVG(R) FROM (SELECT DATEDIFF('2017-12-03', DATE(FROM_UNIXTIME(MAX(timestamp)))) AS R FROM user_behavior WHERE behavior_type='buy' AND timestamp BETWEEN 1511539200 AND 1512316799 GROUP BY user_id) t)
            THEN '高' ELSE '低'
        END AS R_level,
        CASE 
            WHEN COUNT(*) > (SELECT AVG(F) FROM (SELECT COUNT(*) AS F FROM user_behavior WHERE behavior_type='buy' AND timestamp BETWEEN 1511539200 AND 1512316799 GROUP BY user_id) t)
            THEN '高' ELSE '低'
        END AS F_level
    FROM user_behavior
    WHERE behavior_type = 'buy'
      AND timestamp BETWEEN 1511539200 AND 1512316799
    GROUP BY user_id
)
SELECT 
    CONCAT(R_level, '-', F_level) AS 象限,
    COUNT(*) AS 用户数
FROM user_rfm
GROUP BY 象限
ORDER BY 象限;
