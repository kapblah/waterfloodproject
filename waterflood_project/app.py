from pathlib import Path
import numpy as np
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

# ------------------------------------------------------------
# SPE10 Waterflood Monitoring Dashboard
# Reads CSV exports created by export_SPE10_dashboard_data.m
# ------------------------------------------------------------

st.set_page_config(
    page_title="SPE10 Waterflood Monitoring",
    page_icon="🛢️",
    layout="wide",
)

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "dashboard_data"

st.title("SPE10 Waterflood Monitoring Dashboard")
st.caption(
    "Heterogeneous sandstone benchmark | MRST simulation results | "
    "Two injection-rate scenarios"
)

if not DATA_DIR.exists():
    st.error(
        f"Data folder not found: {DATA_DIR}\n\n"
        "Place this app.py file in the project folder that contains dashboard_data."
    )
    st.stop()


@st.cache_data
def load_csv(filename):
    path = DATA_DIR / filename
    if not path.exists():
        raise FileNotFoundError(f"Missing data file: {filename}")
    return pd.read_csv(path)


@st.cache_data
def load_case(rate):
    production = load_csv(f"production_{rate}m3day.csv")
    producers = load_csv(f"individual_producers_{rate}m3day.csv")
    return production, producers


try:
    prod50, producers50 = load_case(50)
    prod100, producers100 = load_case(100)
    grid = load_csv("grid_information.csv").iloc[0]
    porosity = load_csv("reservoir_porosity.csv").to_numpy()
    permeability = load_csv("reservoir_permeability_mD.csv").to_numpy()
except Exception as exc:
    st.error(f"Could not load dashboard data: {exc}")
    st.stop()


# Sidebar controls
st.sidebar.header("Dashboard controls")
case_choice = st.sidebar.selectbox(
    "Production case",
    ["100 m³/day", "50 m³/day"],
    index=0,
)
rate = 100 if case_choice.startswith("100") else 50
production, producer_data = (prod100, producers100) if rate == 100 else (prod50, producers50)

snapshot_year = st.sidebar.selectbox("Water-saturation snapshot", [1, 3, 5], index=2)
st.sidebar.markdown("---")
st.sidebar.caption("Data source: MATLAB / MRST CSV exports")
st.sidebar.caption("No new reservoir simulation is performed by this dashboard.")


# Summary metrics
last = production.iloc[-1]
max_bhp = production["InjectorBHP_bar"].max()
ooip_est = last["CumulativeOil_m3"] / (last["RecoveryFactor_percent"] / 100)

m1, m2, m3, m4, m5 = st.columns(5)
m1.metric("Cumulative oil", f'{last["CumulativeOil_m3"]:,.0f} m³')
m2.metric("Cumulative water", f'{last["CumulativeWater_m3"]:,.0f} m³')
m3.metric("Final water cut", f'{last["WaterCut_percent"]:.1f}%')
m4.metric("Recovery factor*", f'{last["RecoveryFactor_percent"]:.2f}%')
m5.metric("Maximum injector BHP", f"{max_bhp:.1f} bar")

st.caption(
    "*Approximate recovery factor. OOIP is estimated using porosity values "
    "that were regularized with a porosity floor; treat OOIP and recovery "
    "factor as provisional pending sensitivity/validation."
)

tab_overview, tab_prod, tab_front, tab_rock, tab_compare = st.tabs(
    ["Overview", "Production", "Water front", "Reservoir properties", "Injection-rate comparison"]
)

with tab_overview:
    st.subheader(f"{rate} m³/day case — five-year overview")
    c1, c2 = st.columns(2)

    with c1:
        fig = go.Figure()
        fig.add_trace(go.Scatter(
            x=production["Time_years"], y=production["OilRate_m3day"],
            mode="lines", name="Oil rate"
        ))
        fig.add_trace(go.Scatter(
            x=production["Time_years"], y=production["WaterRate_m3day"],
            mode="lines", name="Water rate"
        ))
        fig.update_layout(
            title="Oil and water production rates",
            xaxis_title="Time (years)",
            yaxis_title="Rate (m³/day)",
            hovermode="x unified",
        )
        st.plotly_chart(fig, use_container_width=True)

    with c2:
        fig = px.line(
            production, x="Time_years", y="InjectorBHP_bar",
            title="Injector bottom-hole pressure",
            labels={"Time_years": "Time (years)", "InjectorBHP_bar": "BHP (bar)"},
        )
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Case summary")
    summary = pd.DataFrame(
        {
            "Metric": [
                "Injection rate (m³/day)",
                "Cumulative oil (m³)",
                "Cumulative water (m³)",
                "Final oil rate (m³/day)",
                "Final water rate (m³/day)",
                "Final water cut (%)",
                "Maximum injector BHP (bar)",
                "Approximate recovery factor (%)",
                "Estimated OOIP (m³)",
            ],
            "Value": [
                rate,
                last["CumulativeOil_m3"],
                last["CumulativeWater_m3"],
                last["OilRate_m3day"],
                last["WaterRate_m3day"],
                last["WaterCut_percent"],
                max_bhp,
                last["RecoveryFactor_percent"],
                ooip_est,
            ],
        }
    )
    st.dataframe(summary, hide_index=True, use_container_width=True)


with tab_prod:
    st.subheader("Production performance")
    c1, c2 = st.columns(2)

    with c1:
        fig = go.Figure()
        fig.add_trace(go.Scatter(
            x=production["Time_years"], y=production["CumulativeOil_m3"],
            mode="lines", name="Cumulative oil"
        ))
        fig.add_trace(go.Scatter(
            x=production["Time_years"], y=production["CumulativeWater_m3"],
            mode="lines", name="Cumulative water"
        ))
        fig.update_layout(
            title="Cumulative production",
            xaxis_title="Time (years)",
            yaxis_title="Volume (m³)",
            hovermode="x unified",
        )
        st.plotly_chart(fig, use_container_width=True)

    with c2:
        fig = px.line(
            production, x="Time_years", y="WaterCut_percent",
            title="Field water cut",
            labels={"Time_years": "Time (years)", "WaterCut_percent": "Water cut (%)"},
        )
        fig.update_yaxes(range=[0, 100])
        st.plotly_chart(fig, use_container_width=True)

    st.subheader("Individual producer performance")
    oil_cols = [f"Producer{i}_Oil" for i in range(1, 5)]
    water_cols = [f"Producer{i}_Water" for i in range(1, 5)]

    fig = go.Figure()
    for col in oil_cols:
        fig.add_trace(go.Scatter(
            x=producer_data["Time_years"], y=producer_data[col],
            mode="lines", name=col.replace("_", " ")
        ))
    fig.update_layout(
        title="Oil production rate by producer",
        xaxis_title="Time (years)", yaxis_title="Oil rate (m³/day)",
        hovermode="x unified",
    )
    st.plotly_chart(fig, use_container_width=True)

    fig = go.Figure()
    for col in water_cols:
        fig.add_trace(go.Scatter(
            x=producer_data["Time_years"], y=producer_data[col],
            mode="lines", name=col.replace("_", " ")
        ))
    fig.update_layout(
        title="Water production rate by producer",
        xaxis_title="Time (years)", yaxis_title="Water rate (m³/day)",
        hovermode="x unified",
    )
    st.plotly_chart(fig, use_container_width=True)

    st.download_button(
        "Download selected production history",
        data=production.to_csv(index=False).encode("utf-8"),
        file_name=f"production_{rate}m3day.csv",
        mime="text/csv",
    )


with tab_front:
    st.subheader(f"Vertically averaged water saturation — {rate} m³/day")
    snapshot_file = f"water_saturation_{rate}m3day_year{snapshot_year}.csv"
    try:
        saturation = load_csv(snapshot_file).to_numpy()
        fig = px.imshow(
            saturation,
            origin="lower",
            aspect="auto",
            color_continuous_scale="Turbo",
            zmin=0.15,
            zmax=0.80,
            labels={"x": "Grid X index", "y": "Grid Y index", "color": "Water saturation"},
            title=f"Water saturation after {snapshot_year} year(s)",
        )
        fig.update_layout(height=650)
        st.plotly_chart(fig, use_container_width=True)
        st.caption(
            "Map is the arithmetic average of water saturation across the eight model layers. "
            "It is a vertically averaged view, not a layer-by-layer flow map."
        )
    except Exception as exc:
        st.error(f"Could not load saturation snapshot: {exc}")

    st.markdown("#### Compare water-front development over time")
    cols = st.columns(3)
    for col, yr in zip(cols, [1, 3, 5]):
        with col:
            try:
                arr = load_csv(
                    f"water_saturation_{rate}m3day_year{yr}.csv"
                ).to_numpy()
                mini = px.imshow(
                    arr, origin="lower", aspect="auto",
                    color_continuous_scale="Turbo",
                    zmin=0.15, zmax=0.80,
                    title=f"Year {yr}",
                )
                mini.update_layout(height=260, margin=dict(l=10, r=10, t=40, b=10))
                st.plotly_chart(mini, use_container_width=True)
            except Exception as exc:
                st.warning(f"Year {yr} snapshot unavailable: {exc}")


with tab_rock:
    st.subheader("SPE10 reservoir properties")
    st.write(
        f"Grid: **{int(grid['NX'])} × {int(grid['NY'])} × {int(grid['NZ'])}** "
        f"({int(grid['TotalCells']):,} cells)"
    )
    c1, c2 = st.columns(2)

    with c1:
        fig = px.imshow(
            porosity, origin="lower", aspect="auto",
            color_continuous_scale="Viridis",
            labels={"x": "Grid X index", "y": "Grid Y index", "color": "Porosity"},
            title="Vertically averaged porosity",
        )
        st.plotly_chart(fig, use_container_width=True)

    with c2:
        # Use log colour scaling because SPE10 permeability spans orders of magnitude.
        positive_perm = np.where(permeability > 0, permeability, np.nan)
        log_perm = np.log10(positive_perm)
        fig = px.imshow(
            log_perm, origin="lower", aspect="auto",
            color_continuous_scale="Turbo",
            labels={"x": "Grid X index", "y": "Grid Y index", "color": "log10 permeability (mD)"},
            title="Vertically averaged horizontal permeability (log scale)",
        )
        st.plotly_chart(fig, use_container_width=True)

    st.caption(
        "Porosity and permeability maps are arithmetic averages through the eight layers. "
        "Permeability is shown on a base-10 logarithmic scale because its values span "
        "several orders of magnitude."
    )


with tab_compare:
    st.subheader("Injection-rate sensitivity comparison")
    st.caption(
        "Two completed scenarios are compared. The 150 m³/day case was not simulated."
    )

    rows = []
    for r, df in [(50, prod50), (100, prod100)]:
        end = df.iloc[-1]
        rows.append({
            "Injection rate (m³/day)": r,
            "Cumulative oil (m³)": end["CumulativeOil_m3"],
            "Cumulative water (m³)": end["CumulativeWater_m3"],
            "Final water cut (%)": end["WaterCut_percent"],
            "Final oil rate (m³/day)": end["OilRate_m3day"],
            "Final water rate (m³/day)": end["WaterRate_m3day"],
            "Maximum injector BHP (bar)": df["InjectorBHP_bar"].max(),
            "Approx. recovery factor (%)": end["RecoveryFactor_percent"],
        })

    comparison = pd.DataFrame(rows)
    st.dataframe(comparison, hide_index=True, use_container_width=True)

    metric = st.selectbox(
        "Compare metric",
        [
            "CumulativeOil_m3",
            "CumulativeWater_m3",
            "WaterCut_percent",
            "InjectorBHP_bar",
            "RecoveryFactor_percent",
        ],
        format_func=lambda x: {
            "CumulativeOil_m3": "Cumulative oil (m³)",
            "CumulativeWater_m3": "Cumulative water (m³)",
            "WaterCut_percent": "Water cut (%)",
            "InjectorBHP_bar": "Injector BHP (bar)",
            "RecoveryFactor_percent": "Approximate recovery factor (%)",
        }[x],
    )

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=prod50["Time_years"], y=prod50[metric],
        mode="lines", name="50 m³/day"
    ))
    fig.add_trace(go.Scatter(
        x=prod100["Time_years"], y=prod100[metric],
        mode="lines", name="100 m³/day"
    ))
    fig.update_layout(
        title=f"Comparison: {metric}",
        xaxis_title="Time (years)",
        yaxis_title=metric,
        hovermode="x unified",
    )
    st.plotly_chart(fig, use_container_width=True)

    st.warning(
        "The injector BHP values are simulator outputs under fixed-rate controls. "
        "They are not evidence that the rates are safe or operationally feasible. "
        "No fracture-pressure limit or geomechanical validation is included."
    )

st.divider()
st.caption(
    "Research prototype based on the SPE10 Model 2 rock-property benchmark. "
    "Fluid properties, relative-permeability functions and well controls are "
    "study assumptions unless separately validated against field data."
)
