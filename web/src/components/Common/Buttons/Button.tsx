import styles from "./Button.module.css"

function Button({title}: {title: string}) {
    return <button className={styles.Button}>{title}</button>
}

export default Button;