# ==========================================================
# 数据清洗标准流程（8 步）——模板，字段以淘宝 UserBehavior 为例
# 练习规则：写之前先关掉这段代码，只看中文步骤注释自己写
# ==========================================================
import pandas as pd

# ---------- ① 读入（指定时间列解析、dtype） ----------
df = pd.read_csv(
    'UserBehavior.csv',
    names=['user_id', 'item_id', 'category_id', 'behavior_type', 'timestamp'],
    dtype={'user_id': 'int32', 'item_id': 'int32',
           'category_id': 'int32', 'behavior_type': 'category'},
    parse_dates=[],            # timestamp 是 Unix 秒，读进来再转
)
print(f"原始记录数：{len(df):,}")

# ---------- ② 结构检查：先想清楚"每行代表什么" ----------
# 本数据每行 = 某用户对某商品的一次行为记录（不是订单，不是会话）
print(df.shape)          # (行数, 列数)
print(df.info())         # 各列类型、非空数量，一眼看出哪列有缺失/类型不对
print(df.head())         # 抽查几行，和"每行的含义"对一下
print(df['behavior_type'].unique())   # 类别字段必须看取值范围

# ---------- ③ 去重：先判断重复是否合理，再决定去不去 ----------
# 全列完全相同 = 同一行为被重复记录，不合理，删
n_dup = df.duplicated().sum()
print(f"完全重复记录：{n_dup:,} 行")
df = df.drop_duplicates()
print(f"去重后：{len(df):,} 行（减少 {n_dup:,}）")
# 注意：同一用户对同一商品多条 pv 是合理的，不能按部分列去重

# ---------- ④ 缺失与异常值：识别 → 业务决定 → 记录影响行数 ----------
print(df.isna().sum())   # 每列缺失数
n_na = df.isna().any(axis=1).sum()
df = df.dropna()         # 本数据无缺失则这行不生效；有缺失时按业务决定删/填

# 异常：behavior_type 超出四类、时间戳落在窗口外的先标记
valid_behavior = ['pv', 'cart', 'fav', 'buy']   # 2014 版数据集是 1/2/3/4
n_bad_behavior = (~df['behavior_type'].isin(valid_behavior)).sum()
df = df[df['behavior_type'].isin(valid_behavior)]
print(f"非法行为类型：剔除 {n_bad_behavior:,} 行")

# ---------- ⑤ 时间处理：timestamp +8h 转北京时间（踩过的坑） ----------
# pandas 默认按 UTC 解析，直接 .dt.date 会把 11-25 00:00(CST) 算成 11-24
df['dt'] = pd.to_datetime(df['timestamp'], unit='s') + pd.Timedelta(hours=8)
df = df[(df['dt'] >= '2017-11-25') & (df['dt'] < '2017-12-04')]
print(f"时间窗过滤后：{len(df):,} 行")
print(f"日期范围核验：{df['dt'].min()} ~ {df['dt'].max()}")   # 必须落在窗口内

# ---------- ⑥ 条件过滤（按分析需要） ----------
# 例：只保留 pv/cart/fav/buy 已在上面做过；如需剔除某天：
# df = df[df['dt'].dt.date != pd.Timestamp('2017-12-03').date()]

# ---------- ⑦ 类型转换、字段重命名 ----------
df['date'] = df['dt'].dt.date
df['hour'] = df['dt'].dt.hour
df = df.rename(columns={'category_id': 'cate_id'})
df['behavior_type'] = df['behavior_type'].astype('category')  # 省内存

# ---------- ⑧ 输出前自检：行数对账、关键计数核对 ----------
print("=" * 50)
print(f"清洗后总行数：{len(df):,}")               # 记进报告的"清洗后 N 条"
print("各行为计数（应与后续分析分母一致）：")
print(df['behavior_type'].value_counts())
# 对账：清洗链路每一步剔除多少行，加起来必须等于 原始行数 - 最终行数
print(f"对账：{len(df):,} + 全部剔除行数 = 原始 {100_150_807:,}（数字以你实际读入为准）")

df.to_csv('output/user_behavior_clean.csv', index=False)
