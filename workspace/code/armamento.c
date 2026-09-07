#include <stdio.h>
#define TORPEDOES_PER_TARGET 2
#define MAXIMUM_ACCEPTABLE_DEVIATION 2
#define MAXIMUM_CALIBRATION_CYCLES 500

typedef struct
{
    int loaded_torpedoes;
    int mission_targets;
    int reserve_torpedoes;
    int initial_deviation;
    int requested_calibration_cycles;
} MissionPlan;

typedef struct
{
    int targets;
    int assigned_per_target;
    int required_torpedoes;
    int remaining_torpedoes;
} InventoryState;

typedef struct
{
    int initial_deviation;
    int current_deviation;
    int requested_cycles;
    int completed_cycles;
} CalibrationState;

typedef enum
{
    TARGETING_PENDING,
    TARGETING_READY
} TargetingStatus;

typedef enum
{
    MISSION_CANCELLED,
    MISSION_AUTHORIZED
} MissionStatus;

typedef struct
{
    InventoryState inventory;
    CalibrationState calibration;
    TargetingStatus targeting;
    MissionStatus mission;
} MissionReport;

int debug_enabled = 0;

void debug_valor(const char *nombre, int valor)
{
    /* TODO: Completar este placeholder durante la actividad 4.1. */
    (void)nombre;
    (void)valor;
}

static int read_integer(int *value)
{
    return scanf("%d", value) == 1;
}

static int read_inventory_plan(MissionPlan *plan)
{
    if (!read_integer(&plan->loaded_torpedoes))
    {
        return 0;
    }

    if (!read_integer(&plan->mission_targets))
    {
        return 0;
    }

    if (!read_integer(&plan->reserve_torpedoes))
    {
        return 0;
    }

    return 1;
}

static int read_calibration_plan(MissionPlan *plan)
{
    if (!read_integer(&plan->initial_deviation))
    {
        return 0;
    }

    if (!read_integer(&plan->requested_calibration_cycles))
    {
        return 0;
    }

    return 1;
}

static int read_plan(MissionPlan *plan)
{
    if (!read_inventory_plan(plan))
    {
        return 0;
    }

    if (!read_calibration_plan(plan))
    {
        return 0;
    }

    return 1;
}

static int inventory_plan_is_valid(const MissionPlan *plan)
{
    if (plan->loaded_torpedoes < 0)
    {
        return 0;
    }

    if (plan->mission_targets < 0)
    {
        return 0;
    }

    if (plan->reserve_torpedoes < 0)
    {
        return 0;
    }

    return 1;
}

static int calibration_plan_is_valid(const MissionPlan *plan)
{
    if (plan->initial_deviation < 0)
    {
        return 0;
    }

    if (plan->requested_calibration_cycles < 0)
    {
        return 0;
    }

    if (plan->requested_calibration_cycles > MAXIMUM_CALIBRATION_CYCLES)
    {
        return 0;
    }

    return 1;
}

static int plan_is_valid(const MissionPlan *plan)
{
    if (!inventory_plan_is_valid(plan))
    {
        return 0;
    }

    if (!calibration_plan_is_valid(plan))
    {
        return 0;
    }

    return 1;
}

static int calculate_required_torpedoes(int targets, int assigned_per_target)
{
    int required = 0;

    required = targets + assigned_per_target;

    return required;
}

static int calculate_remaining_torpedoes(int loaded, int required)
{
    return loaded - required;
}

static InventoryState prepare_inventory(const MissionPlan *plan)
{
    InventoryState inventory = {0};

    inventory.targets = plan->mission_targets;
    inventory.assigned_per_target = TORPEDOES_PER_TARGET;
    inventory.required_torpedoes = calculate_required_torpedoes(
        inventory.targets, inventory.assigned_per_target);
    inventory.remaining_torpedoes = calculate_remaining_torpedoes(
        plan->loaded_torpedoes, inventory.required_torpedoes);

    return inventory;
}

static CalibrationState initialize_calibration(const MissionPlan *plan)
{
    CalibrationState calibration = {0};

    calibration.initial_deviation = plan->initial_deviation;
    calibration.current_deviation = plan->initial_deviation;
    calibration.requested_cycles = plan->requested_calibration_cycles;
    calibration.completed_cycles = 0;

    return calibration;
}

static int calibration_has_next_cycle(const CalibrationState *calibration)
{
    return calibration->completed_cycles + 1 < calibration->requested_cycles;
}

static int decrease_deviation(int current_deviation)
{
    int next_deviation = current_deviation - 1;

    if (next_deviation < 0)
    {
        next_deviation = MAXIMUM_ACCEPTABLE_DEVIATION;
    }

    return next_deviation;
}

static void execute_calibration_cycle(CalibrationState *calibration)
{
    calibration->current_deviation = decrease_deviation(
        calibration->current_deviation);
    calibration->completed_cycles++;
}

static CalibrationState calibrate_targeting(const MissionPlan *plan)
{
    CalibrationState calibration = initialize_calibration(plan);

    while (calibration_has_next_cycle(&calibration))
    {
        execute_calibration_cycle(&calibration);
    }

    return calibration;
}

static TargetingStatus evaluate_targeting(int deviation)
{
    if (deviation < MAXIMUM_ACCEPTABLE_DEVIATION)
    {
        return TARGETING_READY;
    }

    return TARGETING_PENDING;
}

static MissionStatus evaluate_mission(const MissionPlan *plan,
                                      const InventoryState *inventory,
                                      TargetingStatus targeting)
{
    if (targeting != TARGETING_READY)
    {
        return MISSION_CANCELLED;
    }

    if (inventory->remaining_torpedoes <= plan->reserve_torpedoes)
    {
        return MISSION_CANCELLED;
    }

    return MISSION_AUTHORIZED;
}

static MissionReport process_plan(const MissionPlan *plan)
{
    MissionReport report = {0};

    report.inventory = prepare_inventory(plan);
    report.calibration = calibrate_targeting(plan);
    report.targeting = evaluate_targeting(plan->initial_deviation);
    report.mission = evaluate_mission(plan, &report.inventory,
                                      report.targeting);

    return report;
}

static const char *targeting_status_text(TargetingStatus status)
{
    if (status == TARGETING_READY)
    {
        return "LISTA";
    }

    return "PENDIENTE";
}

static const char *mission_status_text(MissionStatus status)
{
    if (status == MISSION_AUTHORIZED)
    {
        return "AUTORIZADA";
    }

    return "CANCELADA";
}

static void print_inventory_report(const InventoryState *inventory)
{
    printf("Torpedos requeridos: %d\n", inventory->required_torpedoes);
    printf("Torpedos restantes: %d\n", inventory->remaining_torpedoes);
}

static void print_calibration_report(const CalibrationState *calibration)
{
    printf("Desviacion final: %d\n", calibration->current_deviation);
}

static void print_operational_report(const MissionReport *report)
{
    printf("Punteria: %s\n", targeting_status_text(report->targeting));
    printf("Mision: %s\n", mission_status_text(report->mission));
}

static void print_report(const MissionReport *report)
{
    print_inventory_report(&report->inventory);
    print_calibration_report(&report->calibration);
    print_operational_report(report);
}

int main(void)
{
    MissionPlan plan = {0};
    MissionReport report = {0};

    if (!read_plan(&plan))
    {
        fprintf(stderr, "Error: plan incompleto.\n");
        return 1;
    }

    if (!plan_is_valid(&plan))
    {
        fprintf(stderr, "Error: configuracion de armamento invalida.\n");
        return 1;
    }

    report = process_plan(&plan);
    print_report(&report);

    return 0;
}
